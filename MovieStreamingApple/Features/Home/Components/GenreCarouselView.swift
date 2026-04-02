//
//  GenreCarouselView.swift
//  MovieStreamingApple
//
//  Horizontal scrollable genre chips — equivalent to the website's GenreCarousel.
//

import SwiftUI

struct GenreCarouselView: View {
    let genres: [Genre]
    let isLoading: Bool
    var onGenreTap: ((Genre) -> Void)?

    @Environment(\.themeManager) private var themeManager

    var body: some View {
        if isLoading {
            shimmerView
        } else if !genres.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: DesignTokens.Spacing.sm) {
                    ForEach(genres, id: \.slug) { genre in
                        genreChip(genre)
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.lg)
            }
        }
    }

    // MARK: - Genre Chip

    private func genreChip(_ genre: Genre) -> some View {
        Button {
            onGenreTap?(genre)
        } label: {
            HStack(spacing: 6) {
                Text(genre.name)
                    .font(ThemeFont.display(size: 12, weight: .bold))
                    .textCase(.uppercase)
                if let count = genre.contentCount, count > 0 {
                    Text(count.formatted())
                        .font(ThemeFont.body(size: 10))
                        .foregroundStyle(themeManager.colors.textMuted)
                }
            }
            .foregroundStyle(themeManager.colors.textBody)
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.sm)
            .background(themeManager.colors.overlaySubtle)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(themeManager.colors.border.opacity(0.5), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(genre.name), \(genre.contentCount ?? 0) phim")
    }

    // MARK: - Shimmer Loading

    private var shimmerView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                ForEach(0..<12, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 20)
                        .fill(themeManager.colors.bgCardAlt)
                        .frame(width: 90, height: 36)
                        .shimmer()
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.lg)
        }
    }
}
