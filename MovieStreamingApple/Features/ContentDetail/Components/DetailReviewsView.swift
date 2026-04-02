//
//  DetailReviewsView.swift
//  MovieStreamingApple
//
//  Reviews tab (placeholder matching the website's reviews section).
//

import SwiftUI

struct DetailReviewsView: View {
    @Environment(\.themeManager) private var themeManager

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            // Header bar
            HStack {
                Text("Đánh Giá Từ Người Xem")
                    .font(ThemeFont.body(size: 16, weight: .bold))
                    .foregroundStyle(ThemeColor.textPrimary)

                Spacer()

                Button {
                    // Write review — feature not yet implemented
                } label: {
                    Text("VIẾT ĐÁNH GIÁ")
                        .font(ThemeFont.body(size: 12, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(ThemeColor.textPrimary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            LinearGradient(
                                colors: [themeManager.colors.brand, Color(red: 0.7, green: 0, blue: 0.2)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(true)
                .opacity(0.5)
                .accessibilityHint("Tính năng sắp ra mắt")
            }
            .padding(DesignTokens.Spacing.lg)
            .background(ThemeColor.textPrimary.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(ThemeColor.textPrimary.opacity(0.06), lineWidth: 1)
            )

            // Empty state
            VStack(spacing: DesignTokens.Spacing.lg) {
                Image(systemName: AppIcon.textBubble)
                    .font(ThemeFont.display(size: 36))
                    .foregroundStyle(ThemeColor.textMuted)
                Text("Chưa có đánh giá nào.")
                    .font(ThemeFont.body(size: 14))
                    .foregroundStyle(ThemeColor.textMuted)
                Text("Hãy là người đầu tiên đánh giá phim này!")
                    .font(ThemeFont.body(size: 13))
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 48)
            .background(ThemeColor.textPrimary.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [6]))
                    .foregroundStyle(ThemeColor.textPrimary.opacity(0.08))
            )
        }
    }
}
