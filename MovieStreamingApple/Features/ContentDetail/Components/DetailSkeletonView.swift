//
//  DetailSkeletonView.swift
//  MovieStreamingApple
//
//  Loading skeleton for the content detail page.
//  Mirrors the website's loading skeleton in ContentDetail.tsx.
//

import SwiftUI

struct DetailSkeletonView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Banner skeleton
                Rectangle()
                    .fill(Color(white: 0.12))
                    .frame(height: 350)
                    .shimmer()
                    .overlay(alignment: .bottom) {
                        LinearGradient(
                            colors: [.clear, .black],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 200)
                    }

                VStack(spacing: DesignTokens.Spacing.xl) {
                    // Poster skeleton
                    VStack(spacing: DesignTokens.Spacing.lg) {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(white: 0.12))
                            .frame(width: 220, height: 330)
                            .shimmer()
                            .overlay {
                                Image(systemName: AppIcon.film)
                                    .font(ThemeFont.display(size: 36))
                                    .foregroundStyle(.tertiary)
                            }

                        // Action buttons skeleton
                        VStack(spacing: DesignTokens.Spacing.md) {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(white: 0.12))
                                .frame(width: 220, height: 48)

                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(white: 0.12))
                                .frame(width: 220, height: 48)
                        }
                    }

                    // Title skeleton
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(white: 0.12))
                            .frame(height: 32)
                            .shimmer()

                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(white: 0.12))
                            .frame(width: 200, height: 20)
                            .shimmer()

                        // Rating bar skeleton
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(white: 0.08))
                            .frame(height: 64)

                        // Meta badges skeleton
                        HStack(spacing: 8) {
                            ForEach(0..<4, id: \.self) { _ in
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(white: 0.12))
                                    .frame(width: 70, height: 28)
                            }
                        }

                        // Tab content skeleton
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(white: 0.08))
                            .frame(height: 300)
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.lg)
                .padding(.top, -60)
                .padding(.bottom, DesignTokens.Spacing.xxxl)
            }
        }
        .scrollIndicators(.hidden)
        .ignoresSafeArea(edges: .top)
    }
}

// MARK: - Error View

struct DetailErrorView: View {
    let errorMessage: String
    let retryAction: () async -> Void
    @Environment(\.themeManager) private var themeManager

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Image(systemName: AppIcon.exclamationmarkTriangle)
                .font(ThemeFont.display(size: 48))
                .foregroundStyle(ThemeColor.textMuted)

            Text("Không Tìm Thấy Phim")
                .font(ThemeFont.display(size: 24, weight: .bold))
                .foregroundStyle(ThemeColor.textPrimary)

            Text("Phim bạn tìm không tồn tại hoặc đã bị xoá.")
                .font(ThemeFont.body(size: 14, weight: .light))
                .foregroundStyle(ThemeColor.textMuted)
                .multilineTextAlignment(.center)

            Button {
                Task { await retryAction() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: AppIcon.arrowCounterclockwise)
                    Text("Thử lại")
                }
                .font(ThemeFont.body(size: 14, weight: .bold))
                .foregroundStyle(ThemeColor.textPrimary)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(themeManager.colors.brand)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black)
    }
}

// MARK: - Previews

#Preview("Loading Skeleton") {
    DetailSkeletonView()
        .preferredColorScheme(.dark)
}

#Preview("Error State") {
    DetailErrorView(errorMessage: "Network error") {
        // retry
    }
    .environment(\.themeManager, ThemeManager())
    .preferredColorScheme(.dark)
}
