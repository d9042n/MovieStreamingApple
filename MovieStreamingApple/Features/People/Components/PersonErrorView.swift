//
//  PersonErrorView.swift
//  MovieStreamingApple
//
//  Error state for the person detail page.
//  Extracted from PersonDetailView for readability.
//

import SwiftUI

struct PersonErrorView: View {
    let message: String
    let onRetry: () async -> Void
    let onGoBack: () -> Void

    @Environment(\.themeManager) private var themeManager

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Image(systemName: AppIcon.exclamationmarkTriangleFill)
                .font(ThemeFont.display(size: 36))
                .foregroundStyle(themeManager.colors.highlight)

            Text("Không tìm thấy nghệ sĩ")
                .font(ThemeFont.display(size: 18, weight: .bold))
                .foregroundStyle(ThemeColor.textPrimary)

            Text(message)
                .font(ThemeFont.body(size: 13))
                .foregroundStyle(ThemeColor.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            HStack(spacing: 12) {
                Button {
                    Task { await onRetry() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: AppIcon.arrowClockwise)
                            .font(ThemeFont.body(size: 12, weight: .bold))
                        Text("Thử lại")
                            .font(ThemeFont.body(size: 14, weight: .bold))
                    }
                    .foregroundStyle(ThemeColor.textPrimary)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(themeManager.colors.brand, in: Capsule())
                }

                Button {
                    onGoBack()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: AppIcon.arrowLeft)
                            .font(ThemeFont.body(size: 12, weight: .bold))
                        Text("Quay lại")
                            .font(ThemeFont.body(size: 14, weight: .bold))
                    }
                    .foregroundStyle(ThemeColor.textPrimary)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(ThemeColor.textPrimary.opacity(0.06), in: Capsule())
                    .overlay(Capsule().stroke(ThemeColor.textPrimary.opacity(0.1), lineWidth: 1))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
