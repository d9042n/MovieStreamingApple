//
//  VideoPlayerViewModel.swift
//  MovieStreamingApple
//
//  AVPlayer state management with KVO observation.
//  Handles playback, seeking, time tracking, brightness/volume,
//  system volume control (via hidden MPVolumeView), and player lifecycle.
//

import AVFoundation
import AVKit
import Combine
import MediaPlayer
import SwiftUI
import os

private let logger = Logger(subsystem: "com.d9042n.moviestreaming", category: "VideoPlayer")

// MARK: - Resume Playback Constants
private let kResumeSaveInterval: TimeInterval = 5.0   // Save progress every 5 seconds
private let kResumeThreshold: TimeInterval = 30.0      // Only show resume if progress > 30s
private let kResumeAutoDismiss: TimeInterval = 10.0    // Auto-dismiss toast after 10s
private let kResumeNearEndThreshold: TimeInterval = 60.0 // Don't show resume if within 60s of end

/// Manages AVPlayer state and provides reactive bindings for the player UI.
@Observable
@MainActor
final class VideoPlayerViewModel {

    /// Tracks whether we've already retried the current source (avoids infinite retry loops).
    private var hasRetriedCurrentSource = false

    // MARK: - Player State

    /// The underlying AVPlayer instance.
    private(set) var player: AVPlayer?
    private(set) var playerItem: AVPlayerItem?

    /// Set exclusively by KVO `timeControlObservation` — single source of truth.
    var isPlaying = false
    var isBuffering = true
    var isFinished = false
    var currentTime: TimeInterval = 0
    var duration: TimeInterval = 0
    var bufferedTime: TimeInterval = 0
    var isSeeking = false
    var playbackRate: Float = 1.0

    /// Error state
    var playerError: String?

    // MARK: - Resume Playback State

    /// The saved time to resume from (nil if no saved progress).
    var resumeTime: TimeInterval?
    /// Controls visibility of the resume toast overlay.
    var showResumeToast = false
    /// Content identifiers for building the resume storage key.
    private(set) var movieId: String?
    private(set) var episodeId: String?
    /// Deferred seek: stored here, executed once AVPlayerItem reaches .readyToPlay.
    /// Necessary because seek(to:) clamps to `duration`, which is 0 before ready.
    private var pendingSeekTime: TimeInterval?
    /// Timer task for periodic progress saving.
    private var progressSaveTimer: Task<Void, Never>?
    /// Timer task for auto-dismissing the resume toast.
    private var resumeAutoDismissTimer: Task<Void, Never>?

    // MARK: - Player Source

    /// True when the player was cleaned up but still remembers a valid source URL.
    /// Used by PlayerPageView.onAppear to detect if the player needs reloading
    /// after returning from a pushed navigation destination.
    var needsReload: Bool {
        player?.currentItem == nil && !currentVideoURL.isEmpty
    }

    private(set) var currentVideoURL: String = ""
    private(set) var currentSubtitles: [SubtitleTrack] = []
    private(set) var posterURL: String = ""

    // MARK: - Subtitle State

    /// The currently selected subtitle track (nil = subtitles off).
    var selectedSubtitleTrack: SubtitleTrack?

    /// Parsed subtitle cues from the selected track file.
    private(set) var subtitleCues: [SubtitleCue] = []

    /// The currently active subtitle cue based on playback time.
    var currentSubtitleCue: SubtitleCue?

    /// Shared subtitle appearance settings (persisted via UserDefaults).
    let subtitleSettings = SubtitleSettings()

    /// Intro/Outro skip settings with per-content persistence.
    let skipSettings = SkipContentSettings()

    /// Task for loading/parsing subtitle files.
    private var subtitleLoadTask: Task<Void, Never>?

    // MARK: - HUD Control

    var isHUDVisible = true
    var isLocked = false
    private var hudTimer: Task<Void, Never>?

    // MARK: - Brightness / Volume

    var currentBrightness: CGFloat = 0.5
    var currentVolume: Float = 0
    var showBrightnessIndicator = false
    var showVolumeIndicator = false

    // MARK: - Seek Indicators

    var seekForwardAmount: Int = 0
    var seekBackwardAmount: Int = 0
    var showSeekForward = false
    var showSeekBackward = false

    // MARK: - Long Press Speed

    var isLongPressing = false
    private var savedRate: Float = 1.0
    private var wasPlayingBeforeLongPress = false

    // MARK: - Scrub State (set by gesture layer, read by indicator layer)

    var isScrubbing = false
    var scrubDelta: TimeInterval = 0

    // MARK: - Debounce Tasks (cancel previous before new)

    private var seekForwardTask: Task<Void, Never>?
    private var seekBackwardTask: Task<Void, Never>?
    private var brightnessIndicatorTask: Task<Void, Never>?
    private var volumeIndicatorTask: Task<Void, Never>?

    // MARK: - System Volume (hidden MPVolumeView)

    // NOTE: MPVolumeView placed off-screen is a well-known pattern but fragile.
    // Apple may change behavior in future OS versions. The alpha=0.01
    // keeps it functional (alpha=0 disables the control).
    private var volumeView: MPVolumeView?
    private var volumeSlider: UISlider?

    // MARK: - Observation

    private var timeObserver: Any?
    private var timeControlObservation: NSKeyValueObservation?
    private var itemStatusObservation: NSKeyValueObservation?
    private var loadedTimeObservation: NSKeyValueObservation?
    private var volumeObservation: NSKeyValueObservation?
    private var endTimeObserver: (any NSObjectProtocol)?
    private var skipBoundaryObserver: Any?

    // MARK: - Callbacks

    var onPlaybackFinished: (() -> Void)?
    var onError: (() -> Void)?

    // MARK: - Lifecycle

    init() {
        configureAudioSession()
        syncSystemBrightness()
        syncSystemVolume()
        setupVolumeObserver()
    }

    // No deinit — cleanup() is called explicitly from PlayerPageView.onDisappear
    // Swift 6.2 deinit is nonisolated and cannot access @MainActor properties.

    // MARK: - Audio Session

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .moviePlayback, options: [])
            try session.setActive(true)
        } catch {
            logger.error("Audio session error: \(error.localizedDescription)")
        }
    }

    // MARK: - System Sync

    /// Read current device brightness via window scene (avoids deprecated UIScreen.main).
    private func syncSystemBrightness() {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            currentBrightness = windowScene.screen.brightness
        }
    }

    /// Read the current system volume from AVAudioSession.
    private func syncSystemVolume() {
        currentVolume = AVAudioSession.sharedInstance().outputVolume
    }

    // MARK: - System Volume Setup

    /// Install a hidden MPVolumeView to control system volume programmatically.
    /// Must be called after the view hierarchy is on-screen (window exists).
    func setupSystemVolumeControl() {
        guard volumeView == nil else { return }
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else { return }

        let view = MPVolumeView(frame: CGRect(x: -2000, y: -2000, width: 1, height: 1))
        view.alpha = 0.01
        window.addSubview(view)
        volumeView = view
        volumeSlider = view.subviews.compactMap { $0 as? UISlider }.first
    }

    /// Observe hardware volume button changes via KVO.
    private func setupVolumeObserver() {
        volumeObservation = AVAudioSession.sharedInstance().observe(
            \.outputVolume, options: [.new]
        ) { [weak self] session, _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if !self.showVolumeIndicator {
                    self.currentVolume = session.outputVolume
                }
            }
        }
    }

    // MARK: - Load Source

    /// Load a new HLS video source.
    /// - Parameter resumePosition: Optional resume position in seconds from WatchHistoryManager.
    ///   If provided, this takes priority over the per-key UserDefaults resume.
    func loadSource(url: String, subtitles: [SubtitleTrack] = [], poster: String = "", autoPlay: Bool = false, movieId: String? = nil, episodeId: String? = nil, resumePosition: TimeInterval? = nil, autoResume: Bool = false) {
        // Lightweight reset — preserves AVPlayer instance (no black flash)
        resetForNewSource()
        hasRetriedCurrentSource = false

        currentVideoURL = url
        currentSubtitles = subtitles
        posterURL = poster
        playerError = nil
        isFinished = false
        isBuffering = true

        // Store content IDs for resume key
        self.movieId = movieId
        self.episodeId = episodeId

        guard !url.isEmpty, let videoURL = URL(string: url) else {
            playerError = String(localized: "Không có nguồn phát")
            isBuffering = false
            return
        }

        // Provide standard browser-like HTTP headers so streaming CDNs don't
        // reject the request. Many HLS servers require a valid User-Agent and/or
        // Origin/Referer header to serve segments.
        let headers: [String: String] = [
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 19_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/19.0 Mobile/15E148 Safari/604.1",
            "Origin": "https://d9042n.online",
            "Referer": "https://d9042n.online/"
        ]
        let asset = AVURLAsset(url: videoURL, options: [
            "AVURLAssetHTTPHeaderFieldsKey": headers
        ])
        let item = AVPlayerItem(asset: asset)
        item.preferredForwardBufferDuration = 30
        item.preferredPeakBitRate = selectedQuality.peakBitRate // Apply current quality preference

        if player == nil {
            player = AVPlayer(playerItem: item)
        } else {
            player?.replaceCurrentItem(with: item)
        }

        playerItem = item
        player?.automaticallyWaitsToMinimizeStalling = true
        player?.allowsExternalPlayback = true

        setupObservations()
        setupSystemVolumeControl()

        // Auto-select default subtitle track
        autoSelectDefaultSubtitle()

        // Fetch actual resolutions from the HLS manifest
        fetchAvailableQualities(from: url)

        // Load skip settings for current content
        skipSettings.loadForContent(slug: movieId ?? "")

        // Load saved resume progress (unified: history position takes priority)
        loadResumeProgress(externalPosition: resumePosition, autoResume: autoResume)

        // Start periodic progress saving
        startProgressSaving()

        if autoPlay {
            play()
        }
    }

    // MARK: - Video Quality

    private(set) var availableQualities: [VideoQualityOption] = [.auto]
    var selectedQuality: VideoQualityOption = .auto

    func setVideoQuality(_ quality: VideoQualityOption) {
        selectedQuality = quality
        playerItem?.preferredPeakBitRate = quality.peakBitRate
        logger.info("Set video quality to \(quality.displayName) (Peak Bitrate: \(quality.peakBitRate))")
    }

    private func fetchAvailableQualities(from urlString: String) {
        // Remember the user's prior preference (by resolution) so it survives a
        // retry / episode reload instead of silently snapping back to Auto.
        let previousResolution: String? = {
            if case .fixed(let info) = selectedQuality { return info.resolution }
            return nil
        }()

        // The available list is manifest-specific — reset it. Keep `selectedQuality`
        // until we know whether the new manifest still offers that resolution.
        self.availableQualities = [.auto]

        guard let url = URL(string: urlString) else {
            self.selectedQuality = .auto
            return
        }

        // Skip quality fetching for non-HLS URLs (MP4, etc.)
        // MP4 progressive downloads have a single fixed bitrate — no variants to parse.
        let pathLower = url.pathExtension.lowercased()
        let isLikelyHLS = pathLower == "m3u8" || urlString.lowercased().contains(".m3u8")
        guard isLikelyHLS else {
            logger.info("Non-HLS source (\(pathLower.isEmpty ? "unknown" : pathLower)), quality selection N/A")
            self.selectedQuality = .auto
            self.playerItem?.preferredPeakBitRate = 0
            return
        }

        Task(priority: .background) { [weak self] in
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return }
                guard let content = String(data: data, encoding: .utf8) else { return }

                let parsedQualities = Self.parseM3U8MasterPlaylist(content)
                await MainActor.run {
                    guard let self else { return }
                    guard !parsedQualities.isEmpty else { return }
                    self.availableQualities = [.auto] + parsedQualities.map { .fixed($0) }
                    // Re-apply the user's prior choice if the new manifest still has it,
                    // otherwise fall back to Auto. Keep the player item's cap in sync.
                    if let res = previousResolution {
                        if let match = parsedQualities.first(where: { $0.resolution == res }) {
                            self.selectedQuality = .fixed(match)
                        } else {
                            self.selectedQuality = .auto
                        }
                        self.playerItem?.preferredPeakBitRate = self.selectedQuality.peakBitRate
                    }
                }
            } catch {
                logger.error("Failed to fetch/parse M3U8 Master Playlist: \(error.localizedDescription)")
                await MainActor.run {
                    guard let self else { return }
                    // Manifest unavailable → keep the displayed selection consistent with
                    // the (reset) availableQualities so the quality sheet isn't stuck on a
                    // fixed option that no longer exists.
                    if self.availableQualities.count <= 1, case .fixed = self.selectedQuality {
                        self.selectedQuality = .auto
                        self.playerItem?.preferredPeakBitRate = 0
                    }
                }
            }
        }
    }

    private nonisolated static func parseM3U8MasterPlaylist(_ content: String) -> [VideoQualityInfo] {
        var qualities: [VideoQualityInfo] = []
        let lines = content.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("#EXT-X-STREAM-INF:") {
                var bandwidth: Double = 0
                var width: Int = 0
                var height: Int = 0
                
                // M3U8 attributes are comma-separated
                let parameters = trimmed.dropFirst("#EXT-X-STREAM-INF:".count)
                let attributes = parameters.split(separator: ",")
                
                for attr in attributes {
                    let keyVal = attr.split(separator: "=", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespaces) }
                    guard keyVal.count == 2 else { continue }
                    
                    let key = keyVal[0]
                    let val = keyVal[1].replacingOccurrences(of: "\"", with: "")
                    
                    if key == "BANDWIDTH", let b = Double(val) {
                        // Increase bandwidth allowance by ~20% overhead to ensure AVPlayer doesn't aggressively downgrade
                        bandwidth = b * 1.2 
                    } else if key == "RESOLUTION" {
                        let dims = val.split(separator: "x")
                        if dims.count == 2, let w = Int(dims[0]), let h = Int(dims[1]) {
                            width = w
                            height = h
                        }
                    }
                }
                
                // Only keep qualities that represent a valid video
                if height > 0 && bandwidth > 0 {
                    if !qualities.contains(where: { $0.height == height }) {
                        qualities.append(VideoQualityInfo(resolution: "\(height)p", width: width, height: height, bandwidth: bandwidth))
                    } else if let idx = qualities.firstIndex(where: { $0.height == height }), qualities[idx].bandwidth < bandwidth {
                        // If same height, override with the higher-quality track (better profile)
                        qualities[idx] = VideoQualityInfo(resolution: "\(height)p", width: width, height: height, bandwidth: bandwidth)
                    }
                }
            }
        }
        
        // Sort descending from highest to lowest quality
        return qualities.sorted { $0.height > $1.height }
    }

    // MARK: - Subtitle Track Selection

    /// Select a subtitle track and load its cues.
    func selectSubtitleTrack(_ track: SubtitleTrack) {
        selectedSubtitleTrack = track
        currentSubtitleCue = nil
        subtitleCues = []

        subtitleLoadTask?.cancel()
        subtitleLoadTask = Task {
            do {
                let cues = try await SubtitleParser.parse(from: track.fileUrl)
                guard !Task.isCancelled else { return }
                self.subtitleCues = cues
                logger.info("Loaded \(cues.count) cues for track: \(track.label)")
            } catch {
                logger.error("Subtitle parse error: \(error.localizedDescription)")
                self.subtitleCues = []
            }
        }
    }

    /// Disable subtitles.
    func disableSubtitles() {
        subtitleLoadTask?.cancel()
        selectedSubtitleTrack = nil
        subtitleCues = []
        currentSubtitleCue = nil
    }

    /// Auto-select the default subtitle track (if any has isDefault == true).
    private func autoSelectDefaultSubtitle() {
        // Clear previous subtitle state
        subtitleLoadTask?.cancel()
        selectedSubtitleTrack = nil
        subtitleCues = []
        currentSubtitleCue = nil

        if let defaultTrack = currentSubtitles.first(where: { $0.isDefault }) {
            selectSubtitleTrack(defaultTrack)
        } else if let firstTrack = currentSubtitles.first {
            // If no default, auto-select the first track
            selectSubtitleTrack(firstTrack)
        }
    }

    /// Update the current subtitle cue based on the current playback time.
    /// Called from the periodic time observer.
    private func updateCurrentSubtitleCue() {
        guard !subtitleCues.isEmpty else {
            if currentSubtitleCue != nil { currentSubtitleCue = nil }
            return
        }

        let time = currentTime

        // Check if current cue is still active
        if let current = currentSubtitleCue, current.isActive(at: time) {
            return
        }

        // Binary search for the active cue
        let activeCue = findActiveCue(at: time)
        if activeCue?.id != currentSubtitleCue?.id {
            currentSubtitleCue = activeCue
        }
    }

    /// Find the cue active at the given time.
    ///
    /// Cues are sorted by `startTime` but the parser does NOT guarantee they are
    /// non-overlapping, so a strict disjoint binary search can skip an earlier
    /// long cue. Instead: binary-search the rightmost cue whose `startTime <= time`,
    /// then scan backwards for the first cue still active. The backward scan is
    /// bounded to cues starting within `maxCueLookback` seconds of `time`, which
    /// keeps it O(small) for any realistic cue length.
    private func findActiveCue(at time: TimeInterval) -> SubtitleCue? {
        guard !subtitleCues.isEmpty else { return nil }

        var low = 0
        var high = subtitleCues.count - 1
        var idx = -1
        while low <= high {
            let mid = (low + high) / 2
            if subtitleCues[mid].startTime <= time {
                idx = mid
                low = mid + 1
            } else {
                high = mid - 1
            }
        }

        guard idx >= 0 else { return nil }

        let maxCueLookback: TimeInterval = 30
        let earliestRelevantStart = time - maxCueLookback
        var i = idx
        while i >= 0 {
            let cue = subtitleCues[i]
            if cue.startTime < earliestRelevantStart { break }
            if cue.isActive(at: time) { return cue }
            i -= 1
        }

        return nil
    }

    // MARK: - Playback Controls

    func play() {
        player?.rate = playbackRate
        // isPlaying is set exclusively by KVO timeControlObservation
        scheduleHUDHide()
    }

    func pause() {
        player?.pause()
        // isPlaying is set exclusively by KVO timeControlObservation
        showHUD()
    }

    func togglePlayPause() {
        if isFinished {
            seek(to: 0)
            isFinished = false
            play()
            return
        }

        if isPlaying {
            pause()
        } else {
            play()
        }
        hapticImpact(.light)
    }

    // MARK: - Scrub (gesture-layer swipe seeking)

    /// Update the scrub preview WITHOUT issuing an expensive precise `seek` on
    /// every drag frame. Only `currentTime` (and the indicator HUD) update live;
    /// the real seek is committed once on release via `commitScrub()` (#3).
    func previewScrub(to time: TimeInterval) {
        isScrubbing = true
        currentTime = max(0, min(time, duration))
    }

    /// Commit the scrub: perform a single precise seek to the previewed position.
    func commitScrub() {
        guard isScrubbing else { return }
        let target = currentTime
        isScrubbing = false
        scrubDelta = 0
        seek(to: target)
    }

    // MARK: - Seeking

    /// Seek to a specific time in seconds.
    func seek(to time: TimeInterval) {
        guard let player = player else { return }
        // Only clamp to the upper bound when `duration` is a usable finite value
        // (it is 0/unknown before ready and could be non-finite for live edge cases).
        let upperBounded = (duration.isFinite && duration > 0) ? min(time, duration) : time
        let clampedTime = max(0, upperBounded)
        guard clampedTime.isFinite else { return }
        let cmTime = CMTime(seconds: clampedTime, preferredTimescale: 600)
        isSeeking = true
        currentTime = clampedTime
        player.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            // Always reset isSeeking regardless of `finished` flag
            // to prevent permanently stuck seeking state.
            Task { @MainActor [weak self] in
                self?.isSeeking = false
            }
        }
    }

    /// Seek forward by a number of seconds.
    func seekForward(by seconds: Int = 10) {
        let newTime = min(currentTime + Double(seconds), duration)
        seek(to: newTime)

        seekForwardAmount += seconds
        showSeekForward = true

        seekForwardTask?.cancel()
        seekForwardTask = Task {
            try? await Task.sleep(for: .milliseconds(800))
            guard !Task.isCancelled else { return }
            showSeekForward = false
            seekForwardAmount = 0
        }

        hapticImpact(.light)
        scheduleHUDHide()
    }

    /// Seek backward by a number of seconds.
    func seekBackward(by seconds: Int = 10) {
        let newTime = max(currentTime - Double(seconds), 0)
        seek(to: newTime)

        seekBackwardAmount += seconds
        showSeekBackward = true

        seekBackwardTask?.cancel()
        seekBackwardTask = Task {
            try? await Task.sleep(for: .milliseconds(800))
            guard !Task.isCancelled else { return }
            showSeekBackward = false
            seekBackwardAmount = 0
        }

        hapticImpact(.light)
        scheduleHUDHide()
    }

    // MARK: - Long Press (Speed Boost)

    func startLongPress() {
        guard !isLocked else { return }
        savedRate = playbackRate
        wasPlayingBeforeLongPress = isPlaying
        isLongPressing = true
        // Use playImmediately(atRate:) to bypass buffering wait.
        // Setting rate directly causes AVPlayer to enter .waitingToPlayAtSpecifiedRate
        // which creates a visible stutter. playImmediately skips this.
        player?.playImmediately(atRate: 2.0)
        hapticImpact(.medium)
    }

    func endLongPress() {
        isLongPressing = false
        // Use snapshot wasPlayingBeforeLongPress instead of isPlaying.
        // isPlaying is set asynchronously by KVO and may have stale/incorrect
        // value during the rate transition, causing video to stop unexpectedly.
        if wasPlayingBeforeLongPress {
            player?.rate = savedRate
        } else {
            player?.pause()
        }
        hapticImpact(.light)
    }

    // MARK: - Brightness (Absolute)

    /// Set device brightness to an absolute value (0...1).
    func setBrightness(_ value: CGFloat) {
        let clamped = max(0, min(1, value))
        currentBrightness = clamped
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            windowScene.screen.brightness = clamped
        }

        showBrightnessIndicator = true
        brightnessIndicatorTask?.cancel()
        brightnessIndicatorTask = Task {
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            showBrightnessIndicator = false
        }
    }

    // MARK: - Volume (Absolute, System-level)

    /// Set system volume to an absolute value (0...1).
    func setVolume(_ value: Float) {
        let clamped = max(0, min(1, value))
        currentVolume = clamped
        volumeSlider?.value = clamped

        showVolumeIndicator = true
        volumeIndicatorTask?.cancel()
        volumeIndicatorTask = Task {
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            showVolumeIndicator = false
        }
    }

    // MARK: - HUD Visibility

    func toggleHUD() {
        guard !isLocked else { return }
        if isHUDVisible {
            hideHUD()
        } else {
            showHUD()
        }
    }

    func showHUD() {
        isHUDVisible = true
        if isPlaying {
            scheduleHUDHide()
        }
    }

    func hideHUD() {
        hudTimer?.cancel()
        isHUDVisible = false
    }

    func scheduleHUDHide(after seconds: Double = 4.0) {
        hudTimer?.cancel()
        hudTimer = Task {
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            if isPlaying && !isSeeking && !isLocked {
                isHUDVisible = false
            }
        }
    }

    // MARK: - Lock Screen Orientation

    func toggleLock() {
        isLocked.toggle()
        if isLocked {
            hideHUD()
        } else {
            showHUD()
        }
        hapticImpact(.medium)
    }

    // MARK: - Playback Rate

    func setPlaybackRate(_ rate: Float) {
        playbackRate = rate
        if isPlaying {
            player?.rate = rate
        }
    }

    // MARK: - PiP Support

    var supportsPiP: Bool {
        AVPictureInPictureController.isPictureInPictureSupported()
    }

    // MARK: - Haptic Feedback

    func hapticImpact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    // MARK: - Time Formatting

    static func formatTime(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "0:00" }
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }

    /// Progress as 0...1.
    var progress: Double {
        guard duration > 0 else { return 0 }
        return currentTime / duration
    }

    /// Buffered progress as 0...1.
    var bufferedProgress: Double {
        guard duration > 0 else { return 0 }
        return bufferedTime / duration
    }

    // MARK: - Observations

    private func setupObservations() {
        guard let player = player, let item = playerItem else { return }

        // Periodic time observer — 4x/sec for smooth scrubber + subtitle sync
        let interval = CMTime(seconds: 0.25, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            // Queue is .main — safe to use MainActor.assumeIsolated (no Task allocation)
            MainActor.assumeIsolated {
                guard let self = self, !self.isSeeking, !self.isScrubbing else { return }
                // Guard against NaN/±inf (seek/stall transitions, indefinite timebases)
                // which would poison the scrubber, resume saving and layout math.
                let t = time.seconds
                guard t.isFinite else { return }
                self.currentTime = t
                self.updateCurrentSubtitleCue()
            }
        }

        // Player time control status — SINGLE SOURCE OF TRUTH for isPlaying
        timeControlObservation = player.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                // Guard: During long press, AVPlayer transitions through
                // .waitingToPlayAtSpecifiedRate → .playing which would flip
                // isPlaying and cause race conditions in endLongPress().
                // Skip KVO updates while long pressing to keep state stable.
                guard !self.isLongPressing else { return }
                switch player.timeControlStatus {
                case .playing:
                    self.isPlaying = true
                    self.isBuffering = false
                case .paused:
                    self.isPlaying = false
                case .waitingToPlayAtSpecifiedRate:
                    self.isBuffering = true
                @unknown default:
                    break
                }
            }
        }

        // Item status (ready / failed)
        itemStatusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                switch item.status {
                case .readyToPlay:
                    // Indefinite/live durations report `.seconds == NaN`; sanitize so
                    // progress, seek clamping and skip boundaries never see a non-finite value.
                    let itemDuration = item.duration
                    let seconds = (itemDuration.isNumeric && itemDuration.seconds.isFinite) ? itemDuration.seconds : 0
                    self.duration = seconds
                    self.isBuffering = false
                    self.setupSkipBoundaryObserver(duration: seconds)
                    // Execute deferred seek now that duration is available
                    if let pending = self.pendingSeekTime {
                        self.pendingSeekTime = nil
                        self.seek(to: pending)
                    }
                case .failed:
                    // Log detailed error info for diagnostics
                    if let error = item.error {
                        logger.error("AVPlayerItem failed: \(error.localizedDescription)")
                        let nsError = error as NSError
                        logger.error("Error domain: \(nsError.domain), code: \(nsError.code)")
                        if let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
                            logger.error("Underlying: \(underlyingError.domain) \(underlyingError.code) — \(underlyingError.localizedDescription)")
                        }
                    }
                    // Log AVPlayerItem error log events (network errors, HTTP status codes, etc.)
                    if let errorLog = item.errorLog() {
                        for event in errorLog.events {
                            logger.error("ErrorLog: domain=\(event.errorDomain) code=\(event.errorStatusCode) comment=\(event.errorComment ?? "none") URI=\(event.uri ?? "none")")
                        }
                    }

                    // Auto-retry once before surfacing the error to the user.
                    // Handles transient network glitches or CDN hiccups.
                    if !self.hasRetriedCurrentSource, !self.currentVideoURL.isEmpty {
                        logger.info("Auto-retrying current source...")
                        // Preserve playback position across the retry so the user
                        // resumes where they left off instead of restarting (#4).
                        // Capture BEFORE loadSource — it resets currentTime/resumeTime.
                        let retryResume = self.currentTime > kResumeThreshold
                            ? self.currentTime
                            : self.resumeTime
                        self.loadSource(
                            url: self.currentVideoURL,
                            subtitles: self.currentSubtitles,
                            poster: self.posterURL,
                            autoPlay: true,
                            movieId: self.movieId,
                            episodeId: self.episodeId,
                            resumePosition: retryResume,
                            autoResume: retryResume != nil
                        )
                        // Mark AFTER loadSource — loadSource() resets the flag to false,
                        // so setting it here is what makes "retry exactly once" stick.
                        // (Setting it before would be wiped → unbounded retry storm.)
                        self.hasRetriedCurrentSource = true
                        return
                    }

                    self.playerError = item.error?.localizedDescription ?? String(localized: "Lỗi phát video")
                    self.isBuffering = false
                    self.onError?()
                default:
                    break
                }
            }
        }

        // Loaded time ranges (buffered)
        loadedTimeObservation = item.observe(\.loadedTimeRanges, options: [.new]) { [weak self] item, _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if let range = item.loadedTimeRanges.first?.timeRangeValue {
                    self.bufferedTime = range.start.seconds + range.duration.seconds
                }
            }
        }

        // Playback finished notification
        endTimeObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.isFinished = true
                self.isPlaying = false
                self.showHUD()
                // Clear saved progress when playback finishes naturally
                self.clearResumeProgress()
                self.onPlaybackFinished?()
            }
        }
    }

    // MARK: - Reset for New Source

    /// Removes item-level observations and resets playback state
    /// without destroying the AVPlayer instance (avoids black flash).
    private func resetForNewSource() {
        hudTimer?.cancel()
        seekForwardTask?.cancel()
        seekBackwardTask?.cancel()
        brightnessIndicatorTask?.cancel()
        volumeIndicatorTask?.cancel()
        progressSaveTimer?.cancel()
        progressSaveTimer = nil
        resumeAutoDismissTimer?.cancel()
        resumeAutoDismissTimer = nil

        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
        }
        timeObserver = nil

        if let skipObserver = skipBoundaryObserver {
            player?.removeTimeObserver(skipObserver)
        }
        skipBoundaryObserver = nil

        timeControlObservation?.invalidate()
        timeControlObservation = nil
        itemStatusObservation?.invalidate()
        itemStatusObservation = nil
        loadedTimeObservation?.invalidate()
        loadedTimeObservation = nil

        if let endTimeObserver {
            NotificationCenter.default.removeObserver(endTimeObserver)
        }
        endTimeObserver = nil

        currentTime = 0
        duration = 0
        bufferedTime = 0
        isSeeking = false
        isPlaying = false
        isBuffering = true
        isFinished = false
        showSeekForward = false
        showSeekBackward = false
        seekForwardAmount = 0
        seekBackwardAmount = 0

        // Reset resume state for new source
        resumeTime = nil
        showResumeToast = false
        pendingSeekTime = nil

        // Reset subtitle state for new source
        subtitleLoadTask?.cancel()
        subtitleCues = []
        currentSubtitleCue = nil
    }

    // MARK: - Cleanup (full teardown — called on view disappear)

    func cleanup() {
        // Save progress one last time before cleanup
        saveResumeProgress()
        // Flush any pending debounced subtitle-appearance change so it isn't lost.
        subtitleSettings.flush()
        resetForNewSource()

        volumeObservation?.invalidate()
        volumeObservation = nil

        player?.pause()
        player?.replaceCurrentItem(with: nil)

        volumeView?.removeFromSuperview()
        volumeView = nil
        volumeSlider = nil
    }

    // MARK: - Resume Playback

    /// Storage key based on content identifiers, matching web's format.
    private var resumeStorageKey: String? {
        guard let movieId = movieId, !movieId.isEmpty else { return nil }
        if let episodeId = episodeId, !episodeId.isEmpty {
            return "watch_progress_\(movieId)_\(episodeId)"
        }
        return "watch_progress_\(movieId)"
    }

    /// Load saved resume progress.
    /// - Parameter externalPosition: Resume position from WatchHistoryManager (takes priority).
    /// - Parameter autoResume: If true, immediately seeks to the resume position without showing the toast.
    private func loadResumeProgress(externalPosition: TimeInterval? = nil, autoResume: Bool = false) {
        // Priority 1: External position from unified WatchHistoryManager
        if let external = externalPosition, external > kResumeThreshold {
            resumeTime = external
            if autoResume {
                // Defer seek until readyToPlay — duration is 0 at this point
                pendingSeekTime = external
                return
            } else {
                showResumeToast = true
                scheduleResumeAutoDismiss()
                return
            }
        }

        // Priority 2: Fallback to per-key UserDefaults (backward compat)
        guard let key = resumeStorageKey else { return }
        let saved = UserDefaults.standard.double(forKey: key)
        if saved > kResumeThreshold {
            resumeTime = saved
            if autoResume {
                pendingSeekTime = saved
            } else {
                showResumeToast = true
                scheduleResumeAutoDismiss()
            }
        }
    }

    /// Save current playback time to UserDefaults.
    func saveResumeProgress() {
        guard let key = resumeStorageKey else { return }
        guard currentTime > 0 else { return }
        // Don't save if very close to the end (within 60s)
        if duration > 0 && (duration - currentTime) < kResumeNearEndThreshold {
            // Clear instead — user basically finished
            UserDefaults.standard.removeObject(forKey: key)
            return
        }
        UserDefaults.standard.set(currentTime, forKey: key)
    }

    /// Clear the resume progress entry.
    private func clearResumeProgress() {
        guard let key = resumeStorageKey else { return }
        UserDefaults.standard.removeObject(forKey: key)
    }

    /// Seek to the saved resume time.
    func resumePlayback() {
        guard let time = resumeTime else { return }
        // If item isn't ready yet (duration == 0), defer the seek
        if duration > 0 {
            seek(to: time)
        } else {
            pendingSeekTime = time
        }
        if !isPlaying {
            play()
        }
        showResumeToast = false
        resumeAutoDismissTimer?.cancel()
        hapticImpact(.light)
        logger.info("Resumed playback at \(VideoPlayerViewModel.formatTime(time))")
    }

    /// Dismiss the resume toast without seeking.
    func dismissPlayerResumeToast() {
        resumeAutoDismissTimer?.cancel()
        // Animate the hide and keep `resumeTime` so the outgoing toast retains its
        // content for the removal transition; it is reset by resetForNewSource on
        // the next source. Clearing it in the same frame cuts the slide-out short.
        withAnimation(DesignTokens.Animation.standard) {
            showResumeToast = false
        }
    }

    /// Start periodic progress saving.
    private func startProgressSaving() {
        progressSaveTimer?.cancel()
        progressSaveTimer = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(kResumeSaveInterval))
                guard let self, !Task.isCancelled else { return }
                if self.isPlaying && self.currentTime > 0 {
                    self.saveResumeProgress()
                }
            }
        }
    }

    /// Auto-dismiss the resume toast after configured delay.
    private func scheduleResumeAutoDismiss() {
        resumeAutoDismissTimer?.cancel()
        resumeAutoDismissTimer = Task {
            try? await Task.sleep(for: .seconds(kResumeAutoDismiss))
            guard !Task.isCancelled else { return }
            if showResumeToast {
                withAnimation(DesignTokens.Animation.standard) {
                    showResumeToast = false
                }
            }
        }
    }

    // MARK: - Skip Intro & Outro

    /// Configures boundary time observers for automatic intro/outro skipping.
    /// Called when the player item status becomes .readyToPlay and duration is known.
    private func setupSkipBoundaryObserver(duration: TimeInterval) {
        guard let player = player else { return }

        // Clean up any existing observer
        if let existing = skipBoundaryObserver {
            player.removeTimeObserver(existing)
            skipBoundaryObserver = nil
        }

        var boundaryTimes: [NSValue] = []

        // Intro: if skip duration is set, observe near the very beginning (0.1s).
        // If we hit this boundary and the user hasn't explicitly resumed later in the video,
        // we bounce them to the end of the intro.
        if skipSettings.introSkipDuration > 0 {
            let introTime = CMTime(seconds: 0.1, preferredTimescale: 600)
            boundaryTimes.append(NSValue(time: introTime))
        }

        // Outro: if skip duration is set, observe near the end.
        if skipSettings.outroSkipDuration > 0, duration > skipSettings.outroSkipDuration {
            let outroTimeSeconds = duration - skipSettings.outroSkipDuration
            let outroTime = CMTime(seconds: outroTimeSeconds, preferredTimescale: 600)
            boundaryTimes.append(NSValue(time: outroTime))
        }

        guard !boundaryTimes.isEmpty else { return }

        skipBoundaryObserver = player.addBoundaryTimeObserver(
            forTimes: boundaryTimes,
            queue: .main
        ) { [weak self] in
            MainActor.assumeIsolated {
                guard let self = self else { return }
                self.handleSkipBoundary()
            }
        }
    }

    private func handleSkipBoundary() {
        // `!isFinished` prevents the outro boundary from re-firing onPlaybackFinished()
        // (e.g. when the user replays or scrubs near the end after finishing).
        guard !isSeeking, !isFinished else { return }
        
        let introDuration = skipSettings.introSkipDuration
        let outroDuration = skipSettings.outroSkipDuration
        
        // Check Intro
        if introDuration > 0, currentTime < introDuration {
            logger.info("Auto-skipping intro (\(introDuration)s)")
            seek(to: introDuration)
            hapticImpact(.medium)
            return
        }
        
        // Check Outro
        if outroDuration > 0, duration > outroDuration {
            let threshold = duration - outroDuration
            // Tolerance of 1 second to account for observer firing slightly early or late
            if abs(currentTime - threshold) < 1.0 || currentTime >= threshold {
                logger.info("Hit outro threshold (\(outroDuration)s from end), triggering finish")
                // Mark as finished and skip exactly to the end or call completion
                player?.pause()
                isPlaying = false
                isFinished = true
                showHUD()
                clearResumeProgress()
                onPlaybackFinished?()
            }
        }
    }
}

// MARK: - Display Models

struct VideoQualityInfo: Identifiable, Hashable, Sendable {
    let id: UUID = UUID()
    let resolution: String
    let width: Int
    let height: Int
    let bandwidth: Double
    
    var displayName: String {
        return resolution
    }
}

enum VideoQualityOption: Hashable, Identifiable, Sendable {
    case auto
    case fixed(VideoQualityInfo)
    
    var id: String {
        switch self {
        case .auto: return "auto"
        case .fixed(let info): return info.id.uuidString
        }
    }

    var displayName: String {
        switch self {
        case .auto: return "Tự động"
        case .fixed(let info): return info.displayName
        }
    }

    var peakBitRate: Double {
        switch self {
        case .auto: return 0 // Customary AVPlayer automatic scaling
        case .fixed(let info): return info.bandwidth
        }
    }
}
