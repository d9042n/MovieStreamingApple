//
//  VideoPlayerView.swift
//  MovieStreamingApple
//
//  Composite video player: AVPlayerLayer + gesture layer + HUD overlay.
//  This is the main player component used by PlayerPageView.
//

import SwiftUI
import AVFoundation

/// The main video player view combining video rendering, gestures, and HUD.
struct VideoPlayerView: View {
    @Bindable var viewModel: VideoPlayerViewModel

    @Environment(\.themeManager) private var themeManager

    // Content info displayed on HUD
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
    var onToggleVerticalFullscreen: (() -> Void)?

    // Manual fullscreen (iPad + iPhone unified)
    var isManualFullscreen: Bool = false
    var onToggleManualFullscreen: (() -> Void)?

    // Callbacks
    var onBack: (() -> Void)?
    var onPrevious: (() -> Void)?
    var onNext: (() -> Void)?
    var onEpisodeList: (() -> Void)?
    var onSettings: (() -> Void)?

    var body: some View {
        ZStack {
            // Layer 1: Black background
            ThemeColor.bgBase.ignoresSafeArea()

            // Layer 2: Video rendering
            if let player = viewModel.player {
                AVPlayerLayerView(player: player)
                    .ignoresSafeArea()
            } else {
                noSourcePlaceholder
            }

            // Layer 3: Gesture detection (transparent)
            // Must ignore safe area so taps register everywhere (incl. under Dynamic Island)
            PlayerGestureLayer(viewModel: viewModel)
                .ignoresSafeArea()

            // Layer 4: HUD overlay (controls, progress bar)
            PlayerOverlayView(
                viewModel: viewModel,
                title: title,
                subtitle: subtitle,
                hasPrevious: hasPrevious,
                hasNext: hasNext,
                isSeries: isSeries,
                isEpisodeListVisible: isEpisodeListVisible,
                isVerticalContent: isVerticalContent,
                isVerticalFullScreen: isVerticalFullScreen,
                isManualFullscreen: isManualFullscreen,
                onBack: onBack,
                onPrevious: onPrevious,
                onNext: onNext,
                onEpisodeList: onEpisodeList,
                onSettings: onSettings,
                onToggleVerticalFullscreen: onToggleVerticalFullscreen,
                onToggleManualFullscreen: onToggleManualFullscreen
            )

            // Layer 4.5: Subtitle overlay (between HUD and indicators)
            SubtitleOverlayView(
                cue: viewModel.currentSubtitleCue,
                settings: viewModel.subtitleSettings,
                isHUDVisible: viewModel.isHUDVisible
            )
            .ignoresSafeArea()

            // Layer 5: Gesture indicators (ABOVE HUD so never covered)
            PlayerIndicatorLayer(viewModel: viewModel)
                .ignoresSafeArea()

            // Layer 6: Error overlay
            if let error = viewModel.playerError {
                errorOverlay(message: error)
            }

            // Layer 7: Resume toast (bottom-trailing, above progress bar)
            if viewModel.showResumeToast, let time = viewModel.resumeTime {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        PlayerResumeToast(
                            time: time,
                            onResume: { viewModel.resumePlayback() },
                            onDismiss: { viewModel.dismissPlayerResumeToast() }
                        )
                    }
                    .padding(.trailing, 12)
                    .padding(.bottom, viewModel.isHUDVisible ? 80 : 24)
                }
                .animation(DesignTokens.Animation.standard, value: viewModel.isHUDVisible)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(50)
            }
        }
        .animation(DesignTokens.Animation.standard, value: viewModel.showResumeToast)
        .persistentSystemOverlays(.hidden)
    }

    // MARK: - No Source Placeholder

    private var noSourcePlaceholder: some View {
        ZStack {
            // Poster background with blur
            if !viewModel.posterURL.isEmpty, let url = URL(string: viewModel.posterURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .blur(radius: 30)
                            .scaleEffect(1.15)
                            .clipped()
                    default:
                        ThemeColor.bgBase
                    }
                }
                .overlay(ThemeColor.bgBase.opacity(0.6))
            }

            // Content
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .stroke(ThemeColor.textPrimary.opacity(0.1), lineWidth: 2)
                        .frame(width: 64, height: 64)

                    Image(systemName: AppIcon.playSlash)
                        .font(ThemeFont.display(size: 24, weight: .medium))
                        .foregroundStyle(ThemeColor.textPrimary.opacity(0.6))
                }

                VStack(spacing: 6) {
                    Text("Không có nguồn phát")
                        .font(ThemeFont.body(size: 15, weight: .semibold))
                        .foregroundStyle(ThemeColor.textPrimary.opacity(0.9))

                    Text("Chọn server bên dưới để xem")
                        .font(ThemeFont.body(size: 12))
                        .foregroundStyle(ThemeColor.textPrimary.opacity(0.5))
                }
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Error Overlay

    @ViewBuilder
    private func errorOverlay(message: String) -> some View {
        ZStack {
            // Poster background with blur for error state too
            if !viewModel.posterURL.isEmpty, let url = URL(string: viewModel.posterURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .blur(radius: 30)
                            .scaleEffect(1.15)
                            .clipped()
                    default:
                        ThemeColor.bgBase
                    }
                }
                .overlay(ThemeColor.bgBase.opacity(0.7))
            } else {
                ThemeColor.bgBase.opacity(0.85)
            }

            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(themeManager.colors.highlight.opacity(0.1))
                        .frame(width: 64, height: 64)

                    Image(systemName: AppIcon.exclamationmarkTriangleFill)
                        .font(ThemeFont.display(size: 28))
                        .foregroundStyle(themeManager.colors.highlight)
                }

                VStack(spacing: 6) {
                    Text("Lỗi phát video")
                        .font(ThemeFont.body(size: 15, weight: .semibold))
                        .foregroundStyle(ThemeColor.textPrimary)

                    Text(message)
                        .font(ThemeFont.body(size: 12))
                        .foregroundStyle(ThemeColor.textPrimary.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }

                Button {
                    // Preserve position on manual retry too (#4).
                    let retryResume = viewModel.currentTime > 30
                        ? viewModel.currentTime
                        : viewModel.resumeTime
                    viewModel.loadSource(
                        url: viewModel.currentVideoURL,
                        subtitles: viewModel.currentSubtitles,
                        poster: viewModel.posterURL,
                        autoPlay: true,
                        movieId: viewModel.movieId,
                        episodeId: viewModel.episodeId,
                        resumePosition: retryResume,
                        autoResume: retryResume != nil
                    )
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: AppIcon.arrowClockwise)
                            .font(ThemeFont.body(size: 12, weight: .bold))
                        Text("Thử lại")
                            .font(ThemeFont.body(size: 15, weight: .semibold))
                    }
                    .foregroundStyle(ThemeColor.textPrimary)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(.white.opacity(0.15), in: Capsule())
                    .overlay(Capsule().stroke(ThemeColor.textPrimary.opacity(0.2), lineWidth: 1))
                }
                .accessibilityLabel(Text("Thử lại phát video"))
            }
        }
        .ignoresSafeArea()
    }
}
