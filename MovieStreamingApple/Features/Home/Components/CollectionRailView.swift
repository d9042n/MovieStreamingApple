//
//  CollectionRailView.swift
//  MovieStreamingApple
//
//  Horizontal scrollable content rail — equivalent to the website's CollectionRail.
//  Netflix/Disney+ style editorial carousel.
//

import SwiftUI

struct CollectionRailView: View {
    let collection: ContentCollection

    @Environment(\.themeManager) private var themeManager

    var body: some View {
        if !collection.contents.isEmpty {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                // Section Header
                HStack(spacing: DesignTokens.Spacing.sm) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(themeManager.colors.brand)
                        .frame(width: 3, height: 22)

                    Image(systemName: AppIcon.sparkles)
                        .font(ThemeFont.body(size: 12))
                        .foregroundStyle(themeManager.colors.highlight.opacity(0.7))

                    Text(collection.title)
                        .font(ThemeFont.display(size: 17, weight: .bold))
                        .foregroundStyle(themeManager.colors.textPrimary)
                        .textCase(.uppercase)

                    Spacer()

                    if collection.contents.count > 6 {
                        Text("\(collection.contents.count) phim")
                            .font(ThemeFont.body(size: 11))
                            .foregroundStyle(themeManager.colors.textMuted)
                            .textCase(.uppercase)
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.lg)

                // Horizontal Scroll
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: DesignTokens.Spacing.md) {
                        ForEach(collection.contents) { item in
                            NavigationLink(value: item) {
                                ContentCardView(content: item)
                                    .frame(width: DesignTokens.PosterSize.railWidth)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, DesignTokens.Spacing.lg)
                }
            }
        }
    }
}

// MARK: - All Collections List

struct CollectionRailsView: View {
    let collections: [ContentCollection]
    let isLoading: Bool

    @Environment(\.themeManager) private var themeManager

    var body: some View {
        if isLoading {
            shimmerView
        } else {
            LazyVStack(spacing: DesignTokens.Spacing.xxl) {
                ForEach(collections.filter { !$0.contents.isEmpty }) { collection in
                    CollectionRailView(collection: collection)
                }
            }
        }
    }

    private var shimmerView: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                RoundedRectangle(cornerRadius: 2).fill(themeManager.colors.bgCardAlt).frame(width: 3, height: 22)
                RoundedRectangle(cornerRadius: 4).fill(themeManager.colors.bgCardAlt).frame(width: 150, height: 16).shimmer()
            }
            .padding(.horizontal, DesignTokens.Spacing.lg)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignTokens.Spacing.md) {
                    ForEach(0..<8, id: \.self) { _ in
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.poster)
                                .fill(themeManager.colors.bgCardAlt)
                                .frame(width: DesignTokens.PosterSize.railWidth,
                                       height: DesignTokens.PosterSize.railHeight)
                                .shimmer()
                            RoundedRectangle(cornerRadius: 2).fill(themeManager.colors.bgCardAlt)
                                .frame(width: DesignTokens.PosterSize.railWidth, height: 12)
                                .shimmer()
                        }
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.lg)
            }
        }
    }
}
