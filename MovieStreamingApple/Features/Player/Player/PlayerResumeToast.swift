//
//  PlayerResumeToast.swift
//  MovieStreamingApple
//
//  "Continue watching from X?" popup — glassmorphism toast
//  matching web's ResumeToast.tsx UI exactly.
//  Position: bottom-trailing of the player, above the progress bar.
//  Two actions: Resume (brand button) and Start Over (muted button).
//  Auto-dismiss after 10 seconds or manual dismiss.
//

import SwiftUI

struct PlayerResumeToast: View {
    let time: TimeInterval
    let onResume: () -> Void
    let onDismiss: () -> Void

    @Environment(\.themeManager) private var themeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Message
            HStack(spacing: 4) {
                Text("Xem tiếp từ ")
                    .font(ThemeFont.body(size: 13))
                    .foregroundStyle(ThemeColor.textPrimary.opacity(0.8))

                Text(formattedTime)
                    .font(ThemeFont.body(size: 13, weight: .bold))
                    .foregroundStyle(ThemeColor.textPrimary)

                Text("?")
                    .font(ThemeFont.body(size: 13))
                    .foregroundStyle(ThemeColor.textPrimary.opacity(0.8))
            }

            // Action buttons
            HStack(spacing: 8) {
                // Resume button (brand accent)
                Button {
                    onResume()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: AppIcon.playFill)
                            .font(ThemeFont.body(size: 10, weight: .bold))
                        Text("Xem tiếp")
                            .font(ThemeFont.body(size: 12, weight: .bold))
                    }
                    .foregroundStyle(ThemeColor.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(
                        themeManager.colors.brand,
                        in: RoundedRectangle(cornerRadius: 8)
                    )
                    .shadow(color: themeManager.colors.brand.opacity(0.4), radius: 8, y: 2)
                }
                .buttonStyle(.plain)

                // Start Over button (muted)
                Button {
                    onDismiss()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: AppIcon.arrowCounterclockwise)
                            .font(ThemeFont.body(size: 10, weight: .bold))
                        Text("Từ đầu")
                            .font(ThemeFont.body(size: 12, weight: .bold))
                    }
                    .foregroundStyle(ThemeColor.textPrimary.opacity(0.6))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(
                        .white.opacity(0.1),
                        in: RoundedRectangle(cornerRadius: 8)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(ThemeColor.textPrimary.opacity(0.12), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.5), radius: 16, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(ThemeColor.textPrimary.opacity(0.08), lineWidth: 1)
        )
        // Transition: slide up + fade
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - Helpers

    private var formattedTime: String {
        VideoPlayerViewModel.formatTime(time)
    }
}
