//
//  ContentCardView.swift
//  MovieStreamingApple
//
//  Reusable movie/series poster card — equivalent to the website's ContentCard.
//  Shows poster, title, rating, badges, and streaming meta.
//

import SwiftUI

struct ContentCardView: View {
    let content: Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.themeManager) private var themeManager

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            // MARK: - Poster Image
            // Single container (Color.clear) defines the exact 2:3 ratio.
            // Image and badges are overlays — they cannot affect sizing.
            Color.clear
                .aspectRatio(2 / 3, contentMode: .fit)
                .overlay(alignment: .top) {
                    CachedAsyncImage(url: posterURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    } placeholder: {
                        posterShimmer
                    }
                }
                .overlay(alignment: .topLeading) {
                    // Badges
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        if let quality = content.streamingMeta?.quality, !quality.isEmpty {
                            Text(quality.uppercased())
                                .font(ThemeFont.display(size: 9, weight: .heavy))
                                .foregroundStyle(ThemeColor.textPrimary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(ThemeColor.bgBase.opacity(0.6))
                                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.small))
                        }

                        if content.status == "trailer" {
                            Text("Sắp Chiếu")
                                .font(ThemeFont.display(size: 9, weight: .heavy))
                                .foregroundStyle(ThemeColor.textPrimary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(themeManager.colors.highlight.gradient)
                                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.small))
                        }

                        if let episode = episodeDisplay {
                            Text(episode)
                                .font(ThemeFont.display(size: 9, weight: .bold))
                                .foregroundStyle(ThemeColor.textPrimary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(themeManager.colors.link.gradient)
                                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.small))
                        }
                    }
                    .padding(DesignTokens.Spacing.sm)
                }
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.poster))

            // MARK: - Title (fixed height for grid consistency)
            // Reserve space for 2 lines so all cards in a grid row
            // are the same height regardless of title length.
            Text(content.title)
                .font(ThemeFont.display(size: 15, weight: .semibold))
                .foregroundStyle(themeManager.colors.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, minHeight: 36, alignment: .topLeading)

            // MARK: - Meta Info (fixed height row)
            HStack(spacing: DesignTokens.Spacing.sm) {
                if let rating = content.averageRating, rating > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: AppIcon.starFill)
                            .font(ThemeFont.body(size: 9))
                            .foregroundStyle(themeManager.colors.highlight)
                        Text(String(format: "%.1f", rating))
                            .font(ThemeFont.body(size: 11, weight: .bold))
                            .foregroundStyle(themeManager.colors.textBody)
                    }
                }

                if let year = content.releaseYear {
                    Text(String(year))
                        .font(ThemeFont.body(size: 11))
                        .foregroundStyle(themeManager.colors.textMuted)
                }

                Spacer()

                Image(systemName: content.type == .series ? "tv" : "film")
                    .font(ThemeFont.body(size: 10))
                    .foregroundStyle(themeManager.colors.textMuted)
            }
            .frame(height: 16)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(content.title), \(content.type == .series ? "TV Series" : "Phim")")
        .accessibilityValue(ratingAccessibilityValue)
        .accessibilityHint("Double tap to view details")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Computed Properties

    private var posterURL: URL? {
        guard let urlString = content.posterUrl else { return nil }
        return URL(string: urlString)
    }

    private var episodeDisplay: String? {
        if let current = content.streamingMeta?.episodeCurrent, !current.isEmpty {
            return current
        }
        if content.type == .series, let count = content.episodeCount, count > 0 {
            return "\(count) Tập"
        }
        return nil
    }

    private var ratingAccessibilityValue: String {
        if let rating = content.averageRating, rating > 0 {
            return "Đánh giá \(String(format: "%.1f", rating)) trên 10"
        }
        return "Chưa có đánh giá"
    }

    // MARK: - Placeholder Views

    private var posterPlaceholder: some View {
        Rectangle()
            .fill(.quaternary)
            .aspectRatio(2 / 3, contentMode: .fit)
            .overlay {
                Image(systemName: AppIcon.film)
                    .font(ThemeFont.display(size: 34, weight: .bold))
                    .foregroundStyle(themeManager.colors.textMuted)
            }
    }

    private var posterShimmer: some View {
        Rectangle()
            .fill(.quaternary)
            .aspectRatio(2 / 3, contentMode: .fit)
            .shimmer()
            .overlay {
                ProgressView()
            }
    }
}

// MARK: - Preview

#Preview("Content Card") {
    ContentCardView(content: Content(
        id: "1",
        tmdbId: 123,
        imdbId: nil,
        title: "Spider-Man: Across the Spider-Verse",
        slug: "spider-man-across-the-spider-verse",
        originalTitle: "Spider-Man: Across the Spider-Verse",
        description: nil,
        posterUrl: "https://image.tmdb.org/t/p/w500/8Vt6mWEReuy4Of61Lnj5Xj704m8.jpg",
        backdropUrl: nil,
        trailerUrl: nil,
        releaseDate: "2023-05-31",
        durationMinutes: 140,
        seasonCount: nil,
        episodeCount: nil,
        latestEpisodeAt: nil,
        contentRating: "PG-13",
        averageRating: 8.7,
        ratingCount: 1250,
        totalViews: 125000,
        status: "released",
        network: nil,
        isFeatured: true,
        isPublished: true,
        type: .movie,
        genres: [.string("Action"), .string("Animation")],
        streamingMeta: StreamingMeta(quality: "4K", language: "Vietsub", episodeCurrent: nil, episodeTotal: nil),
        stats: nil,
        regions: nil,
        studios: nil,
        directors: nil,
        writers: nil,
        topCast: nil,
        createdAt: nil,
        updatedAt: nil
    ))
    .frame(width: 160)
    .padding()
}
