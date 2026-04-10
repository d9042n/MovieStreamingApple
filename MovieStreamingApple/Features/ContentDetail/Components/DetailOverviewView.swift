//
//  DetailOverviewView.swift
//  MovieStreamingApple
//
//  Overview tab content: description, keywords, franchise, media gallery,
//  and info sidebar card (directors, release, duration, genres, etc.).
//  Mirrors the website's Overview tab in ContentDetail.tsx.
//

import SwiftUI

struct DetailOverviewView: View {
    let viewModel: ContentDetailViewModel

    @Environment(\.themeManager) private var themeManager

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxl) {
            // MARK: - Description
            if let description = viewModel.strippedDescription, !description.isEmpty {
                Text(description)
                    .font(ThemeFont.body(size: 14, weight: .light))
                    .foregroundStyle(ThemeColor.textMuted)
                    .lineSpacing(5)
                    .tracking(0.3)
            } else {
                Text("Chưa có mô tả.")
                    .font(ThemeFont.body(size: 14, weight: .light))
                    .foregroundStyle(.tertiary)
            }

            // MARK: - Media Gallery
            if !viewModel.allGalleryItems.isEmpty || viewModel.content?.trailerUrl != nil {
                mediaGallerySection
            }

            // MARK: - Info Sidebar Card
            infoSidebarCard
        }
    }

    // MARK: - Media Gallery Section (interactive — reuses Watch page component)

    @ViewBuilder
    private var mediaGallerySection: some View {
        PlayerMediaGallery(
            media: viewModel.media,
            trailerURL: viewModel.content?.trailerUrl,
            contentTitle: viewModel.content?.title ?? ""
        )
    }

    // MARK: - Info Sidebar Card

    @ViewBuilder
    private var infoSidebarCard: some View {
        VStack(spacing: 0) {
            // Directors
            if !viewModel.directors.isEmpty {
                infoRow(icon: AppIcon.person2, label: "Đạo diễn") {
                    Text(viewModel.directors.compactMap(\.name).joined(separator: ", "))
                        .font(ThemeFont.body(size: 13, weight: .medium))
                        .foregroundStyle(themeManager.colors.link)
                }
            }

            // Release date
            if let releaseDate = viewModel.content?.releaseDate {
                infoRow(icon: AppIcon.calendar, label: "Khởi chiếu") {
                    Text(DateFormatting.formatMedium(releaseDate))
                        .font(ThemeFont.body(size: 13, weight: .medium))
                        .foregroundStyle(ThemeColor.textPrimary)
                }
            }

            // Duration for movies
            if viewModel.isMovie, let minutes = viewModel.content?.durationMinutes {
                infoRow(icon: AppIcon.clock, label: "Thời lượng") {
                    Text("\(minutes) phút")
                        .font(ThemeFont.body(size: 13, weight: .medium))
                        .foregroundStyle(ThemeColor.textPrimary)
                }
            }

            // Network for series
            if viewModel.isSeries, let network = viewModel.content?.network, !network.isEmpty {
                infoRow(icon: AppIcon.tv, label: "Kênh") {
                    Text(network)
                        .font(ThemeFont.body(size: 13, weight: .medium))
                        .foregroundStyle(ThemeColor.textPrimary)
                }
            }

            // Regions
            if let regions = viewModel.content?.regions, !regions.isEmpty {
                infoRow(icon: AppIcon.globe, label: "Quốc gia") {
                    Text(regions.map(\.name).joined(separator: ", "))
                        .font(ThemeFont.body(size: 13, weight: .medium))
                        .foregroundStyle(ThemeColor.textPrimary)
                }
            }

            // Content rating
            if let rating = viewModel.content?.contentRating, !rating.isEmpty {
                infoRow(icon: AppIcon.exclamationmarkShield, label: "Phân loại") {
                    Text(rating)
                        .font(ThemeFont.body(size: 13, weight: .bold))
                        .foregroundStyle(themeManager.colors.highlight)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .background(themeManager.colors.highlight.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(themeManager.colors.highlight.opacity(0.2), lineWidth: 1)
                        )
                }
            }

            // Genres
            if let genres = viewModel.content?.genres, !genres.isEmpty {
                infoRow(icon: AppIcon.tag, label: "Thể loại") {
                    FlowLayout(spacing: 6) {
                        ForEach(Array(genres.enumerated()), id: \.offset) { _, genre in
                            Text(genre.name)
                                .font(ThemeFont.body(size: 12, weight: .medium))
                                .foregroundStyle(ThemeColor.textPrimary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(ThemeColor.textPrimary.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                }
            }

            // Studios
            if let studios = viewModel.content?.studios, !studios.isEmpty {
                infoRow(icon: AppIcon.building2, label: "Studio") {
                    FlowLayout(spacing: 6) {
                        ForEach(studios, id: \.slug) { studio in
                            Text(studio.name)
                                .font(ThemeFont.body(size: 12, weight: .medium))
                                .foregroundStyle(ThemeColor.textPrimary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(ThemeColor.textPrimary.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(ThemeColor.textPrimary.opacity(0.08), lineWidth: 1)
                                )
                        }
                    }
                }
            }

            // External links — safe URL creation, no force-unwrap (#1, #2)
            if viewModel.content?.imdbId != nil || viewModel.content?.tmdbId != nil {
                infoRow(icon: AppIcon.link, label: "Liên kết") {
                    HStack(spacing: DesignTokens.Spacing.md) {
                        if let imdbId = viewModel.content?.imdbId,
                           let url = URL(string: "https://www.imdb.com/title/\(imdbId)") {
                            Link("IMDb ↗", destination: url)
                                .font(ThemeFont.body(size: 12, weight: .medium))
                                .foregroundStyle(themeManager.colors.link)
                        }
                        if let tmdbId = viewModel.content?.tmdbId {
                            let tmdbType = viewModel.isSeries ? "tv" : "movie"
                            if let url = URL(string: "https://www.themoviedb.org/\(tmdbType)/\(tmdbId)") {
                                Link("TMDB ↗", destination: url)
                                    .font(ThemeFont.body(size: 12, weight: .medium))
                                    .foregroundStyle(themeManager.colors.link)
                            }
                        }
                    }
                }
            }
        }
        .background(ThemeColor.textPrimary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(ThemeColor.textPrimary.opacity(0.06), lineWidth: 1)
        )
    }

    /// Reusable info row for the sidebar card.
    @ViewBuilder
    private func infoRow<Content: View>(icon: String, label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(ThemeFont.body(size: 12))
                    .foregroundStyle(ThemeColor.textMuted)
                Text(label.uppercased())
                    .font(ThemeFont.body(size: 10, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(ThemeColor.textMuted)
            }

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical, DesignTokens.Spacing.md)
    }

    // MARK: - Helpers

    /// Format ISO date string to localized display — uses shared DateFormatting (#35).
    private func formatDate(_ dateString: String) -> String {
        DateFormatting.formatMedium(dateString)
    }
}
