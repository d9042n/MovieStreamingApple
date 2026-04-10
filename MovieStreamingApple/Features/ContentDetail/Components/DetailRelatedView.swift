//
//  DetailRelatedView.swift
//  MovieStreamingApple
//
//  Related movies/series grid section.
//  Mirrors the website's "Related Content" section in ContentDetail.tsx.
//

import SwiftUI

struct DetailRelatedView: View {
    let contents: [Content]

    @Environment(\.horizontalSizeClass) private var hSizeClass

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            // Section header
            VStack(spacing: DesignTokens.Spacing.sm) {
                HStack {
                    Text("PHIM LIÊN QUAN")
                        .font(ThemeFont.body(size: 16, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(ThemeColor.textPrimary)
                    Spacer()
                }

                Divider()
                    .overlay(ThemeColor.textPrimary.opacity(0.08))
            }

            // Content grid (adaptive columns)
            LazyVGrid(columns: DesignTokens.AdaptiveGrid.posterColumns(hSizeClass), spacing: 12) {
                ForEach(Array(contents.prefix(10)), id: \.id) { content in
                    NavigationLink(value: content) {
                        ContentCardView(content: content)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.top, DesignTokens.Spacing.xl)
    }
}
