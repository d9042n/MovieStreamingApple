//
//  PlayerActionBar.swift
//  MovieStreamingApple
//
//  Netflix/Disney+ inspired action bar:
//  horizontal icon+label buttons evenly spaced.
//

import SwiftUI

struct PlayerActionBar: View {
    let content: Content?
    let nextEpisode: Episode?
    let isSeries: Bool
    let bookmarkCount: Int?

    var onFavorite: (() -> Void)?
    var onBookmark: (() -> Void)?
    var onShare: (() -> Void)?
    var onNextEpisode: (() -> Void)?

    @Environment(\.themeManager) private var themeManager

    var body: some View {
        HStack(spacing: 0) {
            // MARK: [UNIMPLEMENTED] My List button — hidden for App Store review
            // No favorite/list system implemented yet
            // actionButton(
            //     icon: AppIcon.plus,
            //     label: "Danh sách",
            //     isComingSoon: true
            // ) { }

            // MARK: [UNIMPLEMENTED] Rate button — hidden for App Store review
            // No rating submission API implemented yet
            // actionButton(
            //     icon: AppIcon.handThumbsup,
            //     label: "Đánh giá",
            //     isComingSoon: true
            // ) { }

            // Share (functional)
            actionButton(
                icon: AppIcon.paperplane,
                label: "Chia sẻ"
            ) {
                onShare?()
            }

            // Next episode (series only)
            if isSeries, nextEpisode != nil {
                Spacer()

                Button {
                    onNextEpisode?()
                } label: {
                    HStack(spacing: 8) {
                        Text("Tập tiếp theo")
                            .font(ThemeFont.body(size: 12, weight: .semibold))
                        Image(systemName: AppIcon.chevronRight)
                            .font(ThemeFont.body(size: 11, weight: .bold))
                    }
                    .foregroundStyle(ThemeColor.textPrimary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(themeManager.colors.brand, in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func actionButton(icon: String, label: String, isComingSoon: Bool = false, action: @escaping () -> Void) -> some View {
        Button {
            if isComingSoon {
                // Haptic feedback so user knows the tap registered
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } else {
                action()
            }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(ThemeFont.display(size: 20))
                Text(label)
                    .font(ThemeFont.body(size: 10, weight: .medium))

                if isComingSoon {
                    Text("Sắp ra mắt")
                        .font(ThemeFont.body(size: 7, weight: .bold))
                        .foregroundStyle(themeManager.colors.highlight)
                }
            }
            .foregroundStyle(ThemeColor.textMuted)
            .frame(maxWidth: .infinity)
            .opacity(isComingSoon ? 0.45 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(isComingSoon ? "Sắp ra mắt" : "")
    }
}
