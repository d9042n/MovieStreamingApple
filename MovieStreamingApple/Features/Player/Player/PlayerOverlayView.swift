//
//  PlayerOverlayView.swift
//  MovieStreamingApple
//
//  Custom HUD overlay: top bar (back, title, lock, PiP), center (play/pause),
//  bottom (progress bar, time, fullscreen). Animated show/hide.
//

import SwiftUI

struct PlayerOverlayView: View {
    @Bindable var viewModel: VideoPlayerViewModel

    // Content info
    let title: String
    let subtitle: String?

    // Episode navigation
    let hasPrevious: Bool
    let hasNext: Bool
    let isSeries: Bool
    var isEpisodeListVisible: Bool = false

    // Vertical content (short drama) support
    var isVerticalContent: Bool = false
    var isVerticalFullScreen: Bool = false

    // Manual fullscreen state (iPad + iPhone unified)
    var isManualFullscreen: Bool = false

    @Environment(\.themeManager) private var themeManager

    // Callbacks
    var onBack: (() -> Void)?
    var onPrevious: (() -> Void)?
    var onNext: (() -> Void)?
    var onEpisodeList: (() -> Void)?
    var onSettings: (() -> Void)?
    var onToggleVerticalFullscreen: (() -> Void)?
    var onToggleManualFullscreen: (() -> Void)?

    // Scrubber state
    @State private var isScrubbing = false
    @State private var scrubValue: Double = 0

    var body: some View {
        ZStack {
            // Background gradient for readability
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [.black.opacity(0.7), .clear],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 100)

                Spacer()

                LinearGradient(
                    colors: [.clear, .black.opacity(0.7)],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 120)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .opacity(viewModel.isHUDVisible || viewModel.isLocked ? 1 : 0)

            // Lock button (always visible when locked)
            if viewModel.isLocked {
                lockButton
            }

            // Full HUD — always in the layout to prevent jitter,
            // visibility controlled via opacity.
            VStack(spacing: 0) {
                topBar
                Spacer()
                centerControls
                Spacer()
                bottomBar
            }
            .opacity(viewModel.isHUDVisible && !viewModel.isLocked ? 1 : 0)
            .allowsHitTesting(viewModel.isHUDVisible && !viewModel.isLocked)

            // Buffering indicator
            if viewModel.isBuffering && !viewModel.isFinished {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
                    .allowsHitTesting(false)
            }
        }
        .animation(DesignTokens.Animation.quick, value: viewModel.isHUDVisible)
        .animation(DesignTokens.Animation.quick, value: viewModel.isLocked)
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: 16) {
            // Back button
            Button {
                onBack?()
            } label: {
                Image(systemName: AppIcon.chevronLeft)
                    .font(ThemeFont.display(size: 20, weight: .semibold))
                    .foregroundStyle(ThemeColor.textPrimary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(Text("Quay lại"))

            // Title
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(ThemeFont.display(size: 15, weight: .bold))
                    .foregroundStyle(ThemeColor.textPrimary)
                    .lineLimit(1)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(ThemeFont.body(size: 11))
                        .foregroundStyle(ThemeColor.textPrimary.opacity(0.7))
                        .lineLimit(1)
                }
            }

            Spacer()

            // Lock button
            Button {
                viewModel.toggleLock()
            } label: {
                Image(systemName: viewModel.isLocked ? "lock.fill" : "lock.open")
                    .font(ThemeFont.body(size: 16, weight: .medium))
                    .foregroundStyle(ThemeColor.textPrimary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(Text(viewModel.isLocked ? "Mở khóa điều khiển" : "Khóa điều khiển"))

            // Episode list (series only)
            if isSeries {
                Button {
                    onEpisodeList?()
                } label: {
                    Image(systemName: isEpisodeListVisible ? "xmark" : "list.bullet")
                        .font(ThemeFont.body(size: 16, weight: .medium))
                        .foregroundStyle(ThemeColor.textPrimary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                        .contentTransition(.symbolEffect(.replace))
                }
                .accessibilityLabel(Text("Danh sách tập"))
            }

            // Settings
            Button {
                onSettings?()
            } label: {
                Image(systemName: AppIcon.gearshape)
                    .font(ThemeFont.body(size: 16, weight: .medium))
                    .foregroundStyle(ThemeColor.textPrimary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(Text("Cài đặt"))
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - Center Controls

    private var centerControls: some View {
        HStack(spacing: 24) {
            // Previous episode
            if isSeries {
                Button {
                    onPrevious?()
                } label: {
                    Image(systemName: AppIcon.backwardEndFill)
                        .font(ThemeFont.display(size: 20, weight: .semibold))
                        .foregroundStyle(ThemeColor.textPrimary.opacity(hasPrevious ? 0.8 : 0.25))
                        .frame(width: 40, height: 40)
                        .contentShape(Rectangle())
                }
                .disabled(!hasPrevious)
                .accessibilityLabel(Text("Tập trước"))
            }

            // Seek backward 10s
            Button {
                viewModel.seekBackward(by: 10)
            } label: {
                Image(systemName: AppIcon.gobackward10)
                    .font(ThemeFont.display(size: 22, weight: .bold))
                    .foregroundStyle(ThemeColor.textPrimary)
                    .frame(width: 48, height: 48)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(Text("Tua lùi 10 giây"))

            // Play / Pause (centered)
            Button {
                viewModel.togglePlayPause()
            } label: {
                Image(systemName: playPauseIcon)
                    .font(ThemeFont.display(size: 40, weight: .semibold))
                    .foregroundStyle(ThemeColor.textPrimary)
                    .frame(width: 64, height: 64)
                    .contentShape(Rectangle())
                    .contentTransition(.symbolEffect(.replace))
            }
            .accessibilityLabel(Text(playPauseAccessibilityLabel))

            // Seek forward 10s
            Button {
                viewModel.seekForward(by: 10)
            } label: {
                Image(systemName: AppIcon.goforward10)
                    .font(ThemeFont.display(size: 22, weight: .bold))
                    .foregroundStyle(ThemeColor.textPrimary)
                    .frame(width: 48, height: 48)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(Text("Tua tới 10 giây"))

            // Next episode
            if isSeries {
                Button {
                    onNext?()
                } label: {
                    Image(systemName: AppIcon.forwardEndFill)
                        .font(ThemeFont.display(size: 20, weight: .semibold))
                        .foregroundStyle(ThemeColor.textPrimary.opacity(hasNext ? 0.8 : 0.25))
                        .frame(width: 40, height: 40)
                        .contentShape(Rectangle())
                }
                .disabled(!hasNext)
                .accessibilityLabel(Text("Tập sau"))
            }
        }
    }

    private var playPauseIcon: String {
        if viewModel.isFinished { return "arrow.clockwise" }
        return viewModel.isPlaying ? "pause.fill" : "play.fill"
    }

    private var playPauseAccessibilityLabel: String {
        if viewModel.isFinished { return "Phát lại" }
        return viewModel.isPlaying ? "Tạm dừng" : "Phát"
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        VStack(spacing: 6) {
            // Time row above progress
            HStack {
                Text(currentTimeText)
                    .font(ThemeFont.body(size: 12, weight: .bold))
                    .foregroundStyle(ThemeColor.textPrimary.opacity(0.9))

                Spacer()

                // Playback speed badge
                if viewModel.playbackRate != 1.0 {
                    Text("\(String(format: "%.1f", viewModel.playbackRate))x")
                        .font(ThemeFont.body(size: 10, weight: .bold))
                        .foregroundStyle(ThemeColor.textPrimary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
                }

                Text(totalTimeText)
                    .font(ThemeFont.body(size: 12, weight: .bold))
                    .foregroundStyle(ThemeColor.textPrimary.opacity(0.5))

                // Fullscreen / Rotation
                Button {
                    toggleFullscreen()
                } label: {
                    Image(systemName: fullscreenIcon)
                        .font(ThemeFont.body(size: 16, weight: .bold))
                        .foregroundStyle(ThemeColor.textPrimary.opacity(0.9))
                        .frame(width: 50, height: 50)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(Text(fullscreenAccessibilityLabel))
                .padding(.trailing, -8) // Shift slightly right to align with progress bar edge
            }

            // Progress bar
            progressBar
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }

    // MARK: - Progress Bar (YouTube-style)

    private var progressBar: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let trackHeight: CGFloat = isScrubbing ? 6 : 3

            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: trackHeight / 2)
                    .fill(.white.opacity(0.15))
                    .frame(height: trackHeight)

                // Buffered track
                RoundedRectangle(cornerRadius: trackHeight / 2)
                    .fill(.white.opacity(0.25))
                    .frame(
                        width: width * viewModel.bufferedProgress,
                        height: trackHeight
                    )

                // Current progress track
                RoundedRectangle(cornerRadius: trackHeight / 2)
                    .fill(themeManager.colors.brand)
                    .frame(
                        width: max(0, width * displayProgress),
                        height: trackHeight
                    )

                // Thumb dot
                Circle()
                    .fill(themeManager.colors.brand)
                    .frame(
                        width: isScrubbing ? 16 : 12,
                        height: isScrubbing ? 16 : 12
                    )
                    .shadow(color: .black.opacity(0.3), radius: 2)
                    .offset(x: max(0, width * displayProgress - (isScrubbing ? 8 : 6)))
            }
            .frame(height: 44)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !isScrubbing {
                            // Snapshot the current state when scrub begins
                            viewModel.showHUD()
                        }
                        isScrubbing = true
                        let fraction = max(0, min(1, value.location.x / width))
                        scrubValue = fraction
                        // Do NOT set viewModel.isSeeking here — let seek(to:) own it
                    }
                    .onEnded { value in
                        let fraction = max(0, min(1, value.location.x / width))
                        let targetTime = fraction * viewModel.duration
                        viewModel.seek(to: targetTime)
                        isScrubbing = false
                        viewModel.scheduleHUDHide()
                    }
            )
            .animation(DesignTokens.Animation.quick, value: isScrubbing)
        }
        .frame(height: 44)
        .accessibilityElement()
        .accessibilityLabel(Text("Tiến trình phát"))
        .accessibilityValue(Text("\(currentTimeText) / \(totalTimeText)"))
    }

    private var displayProgress: Double {
        isScrubbing ? scrubValue : viewModel.progress
    }

    // MARK: - Time Text

    private var currentTimeText: String {
        VideoPlayerViewModel.formatTime(
            isScrubbing ? scrubValue * viewModel.duration : viewModel.currentTime
        )
    }

    private var totalTimeText: String {
        VideoPlayerViewModel.formatTime(viewModel.duration)
    }

    // MARK: - Lock Button (visible when locked)

    private var lockButton: some View {
        VStack {
            Spacer()
            HStack {
                Button {
                    viewModel.toggleLock()
                } label: {
                    Image(systemName: AppIcon.lockFill)
                        .font(ThemeFont.display(size: 20, weight: .semibold))
                        .foregroundStyle(ThemeColor.textPrimary)
                        .padding(14)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .accessibilityLabel(Text("Mở khóa điều khiển"))
                .padding(24)
                Spacer()
            }
        }
    }

    // MARK: - Helpers

    private var isCurrentlyLandscape: Bool {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return false }
        return windowScene.interfaceOrientation.isLandscape
    }

    /// Whether the player is currently in a "fullscreen" state.
    /// For vertical content: driven by `isVerticalFullScreen`.
    /// For regular content: driven by device orientation OR manual fullscreen toggle.
    private var isCurrentlyFullscreen: Bool {
        if isVerticalContent { return isVerticalFullScreen }
        return isCurrentlyLandscape || isManualFullscreen
    }

    private var fullscreenIcon: String {
        isCurrentlyFullscreen
            ? "arrow.down.right.and.arrow.up.left"
            : "arrow.up.left.and.arrow.down.right"
    }

    private var fullscreenAccessibilityLabel: String {
        isCurrentlyFullscreen ? "Thoát toàn màn hình" : "Toàn màn hình"
    }

    private func toggleFullscreen() {
        // Vertical content: toggle portrait fullscreen (no rotation)
        if isVerticalContent {
            onToggleVerticalFullscreen?()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            return
        }

        // Toggle manual fullscreen state (works on both iPhone and iPad)
        onToggleManualFullscreen?()

        // On iPhone, also request rotation for native feel
        // (On iPad this is a no-op — iPad ignores programmatic rotation)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            let currentOrientation = windowScene.interfaceOrientation
            let targetOrientation: UIInterfaceOrientationMask = currentOrientation.isLandscape ? .portrait : .landscapeRight
            windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: targetOrientation))
            windowScene.windows.first?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        }

        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}
