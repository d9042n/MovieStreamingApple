//
//  PersonSkeletonView.swift
//  MovieStreamingApple
//
//  Loading skeleton for the person detail page.
//  Extracted from PersonDetailView for readability.
//

import SwiftUI

struct PersonSkeletonView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Backdrop skeleton
                Rectangle()
                    .fill(ThemeColor.textPrimary.opacity(0.04))
                    .frame(height: 260)
                    .shimmer()

                // Centered photo skeleton
                RoundedRectangle(cornerRadius: 16)
                    .fill(ThemeColor.textPrimary.opacity(0.06))
                    .frame(width: 130, height: 173)
                    .shimmer()
                    .offset(y: -50)
                    .padding(.bottom, 8)

                VStack(spacing: DesignTokens.Spacing.xl) {
                    // Name skeleton
                    VStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(ThemeColor.textPrimary.opacity(0.06))
                            .frame(width: 180, height: 26)
                            .shimmer()
                        HStack(spacing: 6) {
                            ForEach(0..<3, id: \.self) { _ in
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(ThemeColor.textPrimary.opacity(0.06))
                                    .frame(width: 55, height: 22)
                            }
                        }
                    }

                    // Stats skeleton
                    RoundedRectangle(cornerRadius: 14)
                        .fill(ThemeColor.textPrimary.opacity(0.04))
                        .frame(height: 70)

                    // Info grid skeleton
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(0..<4, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 12)
                                .fill(ThemeColor.textPrimary.opacity(0.04))
                                .frame(height: 56)
                        }
                    }

                    // Tab skeleton
                    RoundedRectangle(cornerRadius: 16)
                        .fill(ThemeColor.textPrimary.opacity(0.04))
                        .frame(height: 250)
                }
                .padding(.horizontal, DesignTokens.Spacing.lg)
            }
        }
    }
}
