//
//  PlayerIndicatorLayer.swift
//  MovieStreamingApple
//
//  Visual indicators rendered ABOVE the HUD so they're never covered.
//  Shows: seek indicators, speed badge, scrub progress bar, brightness/volume bars.
//  All elements have .allowsHitTesting(false) so they don't block HUD buttons.
//

import SwiftUI

struct PlayerIndicatorLayer: View {
    @Bindable var viewModel: VideoPlayerViewModel

    @Environment(\.themeManager) private var themeManager

    var body: some View {
        ZStack {
            // Seek forward indicator (right side)
            if viewModel.showSeekForward {
                seekIndicator(
                    seconds: viewModel.seekForwardAmount,
                    isForward: true
                )
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 60)
                .transition(.opacity)
                .animation(DesignTokens.Animation.quickOut, value: viewModel.showSeekForward)
            }

            // Seek backward indicator (left side)
            if viewModel.showSeekBackward {
                seekIndicator(
                    seconds: viewModel.seekBackwardAmount,
                    isForward: false
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 60)
                .transition(.opacity)
                .animation(DesignTokens.Animation.quickOut, value: viewModel.showSeekBackward)
            }

            // Long press speed indicator
            if viewModel.isLongPressing {
                speedIndicator()
                    .transition(.opacity)
                    .animation(DesignTokens.Animation.quickOut, value: viewModel.isLongPressing)
            }

            // Scrub: floating time + progress bar at bottom
            if viewModel.isScrubbing {
                VStack(spacing: 0) {
                    Spacer()

                    scrubTimeIndicator()
                        .padding(.bottom, 16)

                    Spacer()

                    // Floating progress bar at bottom (visible when HUD off)
                    if !viewModel.isHUDVisible {
                        floatingProgressBar()
                            .padding(.horizontal, 16)
                            .padding(.bottom, 20)
                    }
                }
                .transition(.opacity)
                .animation(DesignTokens.Animation.quickOut, value: viewModel.isScrubbing)
            }

            // Brightness indicator (left side, vertically centered)
            if viewModel.showBrightnessIndicator {
                verticalIndicator(
                    icon: brightnessIcon,
                    value: viewModel.currentBrightness,
                    color: themeManager.colors.highlight
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 16)
                .transition(.opacity)
                .animation(DesignTokens.Animation.quickOut, value: viewModel.showBrightnessIndicator)
            }

            // Volume indicator (right side, vertically centered)
            if viewModel.showVolumeIndicator {
                verticalIndicator(
                    icon: volumeIcon,
                    value: CGFloat(viewModel.currentVolume),
                    color: themeManager.colors.brand
                )
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 16)
                .transition(.opacity)
                .animation(DesignTokens.Animation.quickOut, value: viewModel.showVolumeIndicator)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: - Seek Indicator

    @ViewBuilder
    private func seekIndicator(seconds: Int, isForward: Bool) -> some View {
        VStack(spacing: 4) {
            Image(systemName: seekSFSymbol(seconds: seconds, isForward: isForward))
                .font(ThemeFont.display(size: 32, weight: .semibold))
                .foregroundStyle(ThemeColor.textPrimary)
                .shadow(color: .black.opacity(0.5), radius: 4)

            Text("\(seconds) \(String(localized: "giây"))")
                .font(ThemeFont.body(size: 10, weight: .bold))
                .foregroundStyle(ThemeColor.textPrimary.opacity(0.8))
        }
    }

    private func seekSFSymbol(seconds: Int, isForward: Bool) -> String {
        let validValues = [5, 10, 15, 30, 45, 60, 75, 90]
        let closest = validValues.min(by: { abs($0 - seconds) < abs($1 - seconds) }) ?? 10
        return isForward ? "goforward.\(closest)" : "gobackward.\(closest)"
    }

    // MARK: - Speed Indicator

    @ViewBuilder
    private func speedIndicator() -> some View {
        HStack(spacing: 6) {
            Image(systemName: AppIcon.forwardFill)
                .font(ThemeFont.body(size: 12))
            Text(String(localized: "2x Tốc độ"))
                .font(ThemeFont.body(size: 12, weight: .bold))
        }
        .foregroundStyle(ThemeColor.textPrimary)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, 50)
    }

    // MARK: - Scrub Time Indicator

    @ViewBuilder
    private func scrubTimeIndicator() -> some View {
        VStack(spacing: 2) {
            Text(VideoPlayerViewModel.formatTime(viewModel.currentTime))
                .font(ThemeFont.display(size: 28, weight: .bold).monospaced())
                .foregroundStyle(ThemeColor.textPrimary)

            HStack(spacing: 4) {
                Image(systemName: viewModel.scrubDelta >= 0 ? "goforward" : "gobackward")
                    .font(ThemeFont.body(size: 11))
                Text(VideoPlayerViewModel.formatTime(abs(viewModel.scrubDelta)))
                    .font(ThemeFont.body(size: 12).monospaced())
            }
            .foregroundStyle(ThemeColor.textPrimary.opacity(0.7))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Floating Progress Bar (shown during scrub when HUD is off)

    @ViewBuilder
    private func floatingProgressBar() -> some View {
        VStack(spacing: 6) {
            HStack {
                Text(VideoPlayerViewModel.formatTime(viewModel.currentTime))
                    .font(ThemeFont.display(size: 11, weight: .medium).monospaced())
                    .foregroundStyle(ThemeColor.textPrimary.opacity(0.8))
                Spacer()
                Text(VideoPlayerViewModel.formatTime(viewModel.duration))
                    .font(ThemeFont.display(size: 11, weight: .medium).monospaced())
                    .foregroundStyle(ThemeColor.textPrimary.opacity(0.4))
            }

            GeometryReader { geo in
                let barWidth = geo.size.width
                let progress = viewModel.duration > 0 ? viewModel.currentTime / viewModel.duration : 0

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.white.opacity(0.2))
                        .frame(height: 4)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(.white.opacity(0.3))
                        .frame(width: barWidth * viewModel.bufferedProgress, height: 4)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(themeManager.colors.brand)
                        .frame(width: max(0, barWidth * progress), height: 4)

                    Circle()
                        .fill(themeManager.colors.brand)
                        .frame(width: 10, height: 10)
                        .offset(x: max(0, barWidth * progress - 5))
                }
            }
            .frame(height: 10)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Vertical Indicator (Brightness / Volume)

    @ViewBuilder
    private func verticalIndicator(icon: String, value: CGFloat, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(ThemeFont.display(size: 20, weight: .semibold))
                .foregroundStyle(color)

            GeometryReader { geo in
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.white.opacity(0.2))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color)
                        .frame(height: geo.size.height * max(0, min(1, value)))
                }
            }
            .frame(width: 4, height: 100)

            Text("\(Int(max(0, min(1, value)) * 100))%")
                .font(ThemeFont.body(size: 10, weight: .bold))
                .foregroundStyle(ThemeColor.textPrimary)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Icon Helpers

    private var volumeIcon: String {
        let vol = viewModel.currentVolume
        if vol <= 0 { return "speaker.slash.fill" }
        if vol < 0.33 { return "speaker.wave.1.fill" }
        if vol < 0.66 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }

    private var brightnessIcon: String {
        let val = viewModel.currentBrightness
        if val < 0.33 { return "sun.min.fill" }
        if val < 0.66 { return "sun.max" }
        return "sun.max.fill"
    }
}
