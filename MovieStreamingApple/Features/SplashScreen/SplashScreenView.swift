//
//  SplashScreenView.swift
//  MovieStreamingApple
//
//  Fullscreen splash screen that plays orientation-aware intro video while
//  concurrently preloading critical app data (Home + Browse).
//
//  ┌──────────────────────────────────────────────────────────────────────┐
//  │ Video Selection:                                                    │
//  │   Portrait  (iPhone / iPad portrait) → SplashScreenVertical.mp4     │
//  │   Landscape (iPad landscape)         → SplashScreenHorizontal.mp4   │
//  │                                                                     │
//  │ Lifecycle:                                                          │
//  │  ① App launches → SplashScreen shown as ZStack overlay              │
//  │  ② Video plays + data fetches fire in parallel                      │
//  │  ③ Video ends → if data ready, begin fade-out                       │
//  │                → if data NOT ready, hold last frame until ready      │
//  │  ④ Smooth opacity crossfade (0.8s) → main ContentView revealed     │
//  └──────────────────────────────────────────────────────────────────────┘
//
//  Audio: Video has embedded audio — we configure AVAudioSession for
//  `.ambient` category so it respects the device silent switch.
//

@preconcurrency import AVFoundation
import SwiftUI
import os

private let logger = Logger(subsystem: "com.d9042n.moviestreaming", category: "SplashScreen")

// MARK: - Splash Phase

private enum SplashPhase: Sendable {
    case idle
    case playing
    case transitioning
    case done
}

// MARK: - Splash Screen View

struct SplashScreenView: View {
    /// Binding back to the parent to dismiss the splash.
    @Binding var isPresented: Bool

    /// Splash phase state machine.
    @State private var phase: SplashPhase = .idle

    /// AVPlayer instance — created once in `.task`.
    @State private var player: AVPlayer?

    /// Opacity for crossfade transition.
    @State private var contentOpacity: Double = 1.0

    // MARK: - Data Prefetch State
    @State private var isVideoFinished = false
    @State private var isDataLoaded = false

    // MARK: - Audio Fade Constants
    /// Duration for volume fade-in at video start (seconds).
    private let audioFadeInDuration: TimeInterval = 0.5
    /// Duration for volume fade-out — matches the visual crossfade (seconds).
    private let audioFadeOutDuration: TimeInterval = 0.8
    /// Timer interval for volume ramping (~60 steps/sec for buttery smooth).
    private let volumeStepInterval: TimeInterval = 1.0 / 60.0

    var body: some View {
        ZStack {
            // Black background — fills entire screen including unsafe areas
            Color.black
                .ignoresSafeArea()

            // Video layer — UIViewController compensates for safe area insets
            // so the AVPlayerLayer covers every pixel of the physical screen
            if let player {
                SplashScreenVideoPlayer(player: player)
                    .ignoresSafeArea()
            }
        }
        .ignoresSafeArea()
        .opacity(contentOpacity)
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .task {
            await startSplashSequence()
        }
    }

    // MARK: - Main Sequence

    private func startSplashSequence() async {
        // Configure audio session — ambient respects silent switch
        configureAudioSession()

        // Select the correct video based on current screen orientation
        let videoName = selectVideoForOrientation()

        guard let videoURL = Bundle.main.url(forResource: videoName, withExtension: "mp4") else {
            logger.error("\(videoName).mp4 not found in bundle — skipping splash")
            dismissSplash()
            return
        }

        // Create player — start at volume 0 for smooth fade-in
        let avPlayer = AVPlayer(url: videoURL)
        avPlayer.allowsExternalPlayback = false
        avPlayer.volume = 0.0
        self.player = avPlayer
        phase = .playing

        // Run video playback and data fetch concurrently using async let
        async let videoTask: Void = runVideoPlayback(player: avPlayer)
        async let dataTask: Void = runDataPrefetch()

        // Wait for both to complete
        _ = await (videoTask, dataTask)
    }

    // MARK: - Orientation-Aware Video Selection

    /// Picks the correct video file based on the device's current orientation.
    /// - Portrait (9:16): `SplashScreenVertical`   — iPhone, iPad portrait
    /// - Landscape (16:9): `SplashScreenHorizontal` — iPad landscape
    private func selectVideoForOrientation() -> String {
        let screenBounds = UIScreen.main.bounds
        let isLandscape = screenBounds.width > screenBounds.height

        if isLandscape {
            logger.info("Landscape detected — using SplashScreenHorizontal")
            return "SplashScreenHorizontal"
        } else {
            logger.info("Portrait detected — using SplashScreenVertical")
            return "SplashScreenVertical"
        }
    }

    // MARK: - Video Playback

    private func runVideoPlayback(player: AVPlayer) async {
        // Set up end-of-playback listener before starting
        let notifications = NotificationCenter.default.notifications(
            named: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem
        )

        // Start playback and fade audio in
        player.play()
        fadeVolume(player: player, from: 0.0, to: 1.0, duration: audioFadeInDuration)

        // Fire-and-forget: schedule crossfade to begin `audioFadeOutDuration`
        // seconds BEFORE the video ends, so it completes on the last frame.
        Task { @MainActor in
            await scheduleFadeOutBeforeEnd(player: player)
        }

        // Await end-of-playback — by the time this fires, the crossfade
        // should already be complete (or nearly so).
        for await _ in notifications {
            break
        }

        // Video ended — crossfade has finished
        isVideoFinished = true
        logger.info("Splash video finished — crossfade complete")
        checkAndDismiss()
    }

    /// Calculates when to trigger the crossfade so it finishes exactly
    /// at the video's last frame. Sleeps until `duration - fadeOutDuration`,
    /// then kicks off both audio volume ramp-down and visual opacity fade.
    private func scheduleFadeOutBeforeEnd(player: AVPlayer) async {
        guard let item = player.currentItem else { return }

        do {
            let duration = try await item.asset.load(.duration)
            guard duration.isValid, !duration.isIndefinite else { return }

            let totalSeconds = CMTimeGetSeconds(duration)
            // Don't start fade before the fade-in completes
            let fadeStart = max(audioFadeInDuration, totalSeconds - audioFadeOutDuration)

            try await Task.sleep(for: .seconds(fadeStart))

            // Only start fade if we haven't already transitioned (e.g. early dismiss)
            guard phase == .playing else { return }
            phase = .transitioning

            // Audio fade-out: current volume → 0 over fadeOutDuration
            fadeVolume(player: player, from: player.volume, to: 0.0, duration: audioFadeOutDuration)

            // Visual fade-out: opacity 1 → 0, synced with audio
            withAnimation(.easeOut(duration: audioFadeOutDuration)) {
                contentOpacity = 0.0
            }

            logger.info("Crossfade started — \(audioFadeOutDuration)s before video end")
        } catch {
            // Task was cancelled (e.g., early dismiss) — no-op
        }
    }

    // MARK: - Data Prefetch

    /// Prefetches the same data HomeViewModel needs so URLSession caches warm up.
    /// When HomeView loads, its identical requests hit the URLSession cache → instant.
    private func runDataPrefetch() async {
        let apiClient: APIClientProtocol = APIClient()

        // Fire all critical requests in parallel — mirrors HomeViewModel.fetchAll()
        await withTaskGroup(of: Void.self) { group in
            // Movies
            group.addTask { _ = try? await apiClient.fetchContents(params: "type=movie&sort_by=views&sort_order=desc&page_size=10") }
            group.addTask { _ = try? await apiClient.fetchContents(params: "type=movie&status=trailer&sort_by=release_date&sort_order=desc&page_size=10") }
            group.addTask { _ = try? await apiClient.fetchContents(params: "type=movie&sort_by=rating&sort_order=desc&page_size=10") }
            group.addTask { _ = try? await apiClient.fetchContents(params: "type=movie&sort_by=latest_episode&sort_order=desc&page_size=10") }

            // Series
            group.addTask { _ = try? await apiClient.fetchContents(params: "type=series&sort_by=views&sort_order=desc&page_size=10") }
            group.addTask { _ = try? await apiClient.fetchContents(params: "type=series&status=trailer&sort_by=release_date&sort_order=desc&page_size=10") }
            group.addTask { _ = try? await apiClient.fetchContents(params: "type=series&sort_by=rating&sort_order=desc&page_size=10") }
            group.addTask { _ = try? await apiClient.fetchContents(params: "type=series&sort_by=latest_episode&sort_order=desc&page_size=10") }

            // Genres, Blog, Collections
            group.addTask { _ = try? await apiClient.fetchGenres() }
            group.addTask { _ = try? await apiClient.fetchBlogPosts() }
            group.addTask { _ = try? await apiClient.fetchCollections() }

            await group.waitForAll()
        }

        // Data finished
        isDataLoaded = true
        logger.info("Data prefetch completed")
        checkAndDismiss()
    }

    // MARK: - Transition Logic

    /// Called when video ends or data finishes loading.
    /// Dismisses the splash only when BOTH are complete.
    /// By this point the crossfade has already finished during the video.
    private func checkAndDismiss() {
        guard isVideoFinished, isDataLoaded else { return }
        dismissSplash()
    }

    // MARK: - Audio Volume Fade

    /// Smoothly ramps the player volume from `from` → `to` over `duration` seconds.
    /// Uses a high-frequency Timer on the main run loop for buttery-smooth transitions.
    /// The easing curve is applied via an ease-in-out sine function for a natural feel.
    private func fadeVolume(player: AVPlayer, from startVolume: Float, to endVolume: Float, duration: TimeInterval) {
        let totalSteps = Int(duration / volumeStepInterval)
        guard totalSteps > 0 else {
            player.volume = endVolume
            return
        }

        var currentStep = 0

        // Use DispatchSource timer for precise, non-blocking volume ramping
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now(), repeating: volumeStepInterval)
        timer.setEventHandler { [weak player] in
            guard let player else {
                timer.cancel()
                return
            }

            currentStep += 1
            let progress = min(Float(currentStep) / Float(totalSteps), 1.0)

            // Ease-in-out sine curve for natural audio perception
            // This matches human perception better than linear ramping
            let easedProgress = 0.5 * (1.0 - cos(progress * .pi))

            player.volume = startVolume + (endVolume - startVolume) * easedProgress

            if currentStep >= totalSteps {
                player.volume = endVolume // Ensure exact final value
                timer.cancel()
            }
        }
        timer.resume()
    }

    private func dismissSplash() {
        // Clean up AVPlayer
        player?.pause()
        player = nil

        // Deactivate audio session used by splash
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        isPresented = false
    }

    // MARK: - Audio Session

    private func configureAudioSession() {
        do {
            // .ambient = respects silent switch, mixes with other audio
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            logger.warning("Failed to configure audio session: \(error.localizedDescription)")
        }
    }
}
