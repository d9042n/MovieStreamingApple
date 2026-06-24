//
//  DetailEpisodesView.swift
//  MovieStreamingApple
//
//  Episodes tab: expandable seasons with episode grids + special episodes section.
//  Mirrors the website's Episodes tab in ContentDetail.tsx.
//

import SwiftUI

struct DetailEpisodesView: View {
    @Bindable var viewModel: ContentDetailViewModel

    @Environment(\.themeManager) private var themeManager
    @Environment(\.horizontalSizeClass) private var hSizeClass

    /// Adaptive columns for episode thumbnail grids
    private var episodeColumns: [GridItem] {
        if hSizeClass == .regular {
            return [GridItem(.adaptive(minimum: 180, maximum: 280), spacing: 12)]
        } else {
            return [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10),
            ]
        }
    }

    var body: some View {
        if viewModel.seasons.isEmpty {
            emptyState
        } else {
            VStack(spacing: DesignTokens.Spacing.lg) {
                // Regular seasons
                ForEach(viewModel.regularSeasons, id: \.id) { season in
                    seasonSection(season)
                }

                // Special episodes section
                if viewModel.hasSpecialEpisodes {
                    specialEpisodesSection
                }
            }
        }
    }

    // MARK: - Season Section

    @ViewBuilder
    private func seasonSection(_ season: Season) -> some View {
        let seasonNum = season.seasonNumber ?? 1
        let isExpanded = viewModel.expandedSeason == seasonNum
        let episodes = viewModel.standardEpisodes(for: seasonNum)

        VStack(spacing: 0) {
            // Season Header
            Button {
                Task { await viewModel.toggleSeason(seasonNum) }
            } label: {
                HStack(spacing: DesignTokens.Spacing.md) {
                    // Season poster
                    if let posterUrl = season.posterUrl,
                       let url = URL(string: posterUrl) {
                        CachedAsyncImage(url: url) { image in
                            image.resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 48, height: 72, alignment: .top)
                        } placeholder: {
                            Color(white: 0.12)
                        }
                        .frame(width: 48, height: 72)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(ThemeColor.textPrimary.opacity(0.08), lineWidth: 1)
                        )
                    }

                    // Season info
                    VStack(alignment: .leading, spacing: 4) {
                        Text(season.title)
                            .font(ThemeFont.body(size: 15, weight: .bold))
                            .foregroundStyle(ThemeColor.textPrimary)
                            .lineLimit(1)

                        HStack(spacing: DesignTokens.Spacing.md) {
                            if let epCount = season.episodeCount {
                                Text("\(epCount) tập")
                                    .font(ThemeFont.body(size: 12))
                                    .foregroundStyle(ThemeColor.textMuted)
                            }
                            if let airDate = season.airDate {
                                Text("• \(formatShortDate(airDate))")
                                    .font(ThemeFont.body(size: 11))
                                    .foregroundStyle(ThemeColor.textMuted)
                            }
                        }
                    }

                    Spacer()

                    Image(systemName: AppIcon.chevronDown)
                        .font(ThemeFont.body(size: 14, weight: .medium))
                        .foregroundStyle(ThemeColor.textMuted)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .animation(DesignTokens.Animation.standard, value: isExpanded)
                }
                .padding(DesignTokens.Spacing.lg)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Episodes Grid
            if isExpanded {
                VStack(spacing: 0) {
                    Divider()
                        .overlay(ThemeColor.textPrimary.opacity(0.06))

                    if viewModel.isLoadingEpisodes && episodes.isEmpty {
                        episodeSkeletonGrid
                    } else if viewModel.episodeLoadError != nil {
                        episodeLoadErrorState
                    } else if episodes.isEmpty {
                        Text("Chưa có thông tin tập phim.")
                            .font(ThemeFont.body(size: 14))
                            .foregroundStyle(ThemeColor.textMuted)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 32)
                    } else {
                        episodeGrid(episodes, seasonNum: seasonNum)
                    }
                }
                .transition(.opacity)
            }
        }
        .background(ThemeColor.textPrimary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(ThemeColor.textPrimary.opacity(0.06), lineWidth: 1)
        )
        .animation(DesignTokens.Animation.standard, value: isExpanded)
    }

    // MARK: - Episode Grid

    @ViewBuilder
    private func episodeGrid(_ episodes: [Episode], seasonNum: Int) -> some View {
        LazyVGrid(columns: episodeColumns, spacing: 10) {
            ForEach(episodes, id: \.id) { ep in
                episodeCard(ep)
            }
        }
        .padding(DesignTokens.Spacing.lg)
    }

    @ViewBuilder
    private func episodeCard(_ ep: Episode) -> some View {
        NavigationLink(
            value: PlayerDestination(
                slug: viewModel.content?.effectiveSlug ?? "",
                type: .series,
                seasonNumber: ep.seasonNumber,
                episodeNumber: ep.episodeNumber
            )
        ) {
            VStack(alignment: .leading, spacing: 0) {
                // Thumbnail with play overlay
                ZStack {
                    if let thumbUrl = ep.thumbnailUrl,
                       let url = URL(string: thumbUrl) {
                        CachedAsyncImage(url: url) { image in
                            image.resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Color(white: 0.12)
                        }
                    } else {
                        Color(white: 0.08)
                            .overlay {
                                Image(systemName: AppIcon.film)
                                    .font(ThemeFont.display(size: 20))
                                    .foregroundStyle(.tertiary)
                            }
                    }

                    // Play icon overlay
                    Circle()
                        .fill(.black.opacity(0.5))
                        .frame(width: 32, height: 32)
                        .overlay {
                            Image(systemName: AppIcon.playFill)
                                .font(ThemeFont.body(size: 12))
                                .foregroundStyle(ThemeColor.textPrimary)
                                .offset(x: 1)
                        }

                    // Duration badge
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            if let duration = ep.formattedDuration {
                                Text(duration)
                                    .font(ThemeFont.display(size: 10).monospaced())
                                    .foregroundStyle(ThemeColor.textPrimary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.black.opacity(0.8))
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                    .padding(6)
                            }
                        }
                    }
                }
                .aspectRatio(16 / 9, contentMode: .fill)
                .clipped()

                // Episode info
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tập \(ep.episodeNumber ?? 0)")
                        .font(ThemeFont.body(size: 12, weight: .bold))
                        .foregroundStyle(ThemeColor.textPrimary)

                    if let title = ep.title,
                       title != String(ep.episodeNumber ?? 0) {
                        Text(title)
                            .font(ThemeFont.body(size: 10))
                            .foregroundStyle(ThemeColor.textMuted)
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            }
            .background(ThemeColor.textPrimary.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(ThemeColor.textPrimary.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Tập \(ep.episodeNumber ?? 0), \(ep.title ?? "")")
        .accessibilityHint("Nhấn để xem")
    }

    // MARK: - Special Episodes

    @ViewBuilder
    private var specialEpisodesSection: some View {
        let isExpanded = viewModel.expandedSeason == -1
        // specialEpisodes ALREADY includes season-0 episodes — don't prepend them
        // again or each season-0 episode is counted/rendered twice (duplicate ids).
        let specials = viewModel.specialEpisodes

        VStack(spacing: 0) {
            Button {
                Task { await viewModel.toggleSeason(-1) }
            } label: {
                HStack(spacing: DesignTokens.Spacing.md) {
                    // Star icon instead of poster
                    RoundedRectangle(cornerRadius: 8)
                        .fill(themeManager.colors.highlight.opacity(0.1))
                        .frame(width: 48, height: 72)
                        .overlay {
                            Image(systemName: AppIcon.starFill)
                                .font(ThemeFont.display(size: 20))
                                .foregroundStyle(themeManager.colors.highlight)
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(themeManager.colors.highlight.opacity(0.2), lineWidth: 1)
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Tập Đặc Biệt")
                            .font(ThemeFont.body(size: 15, weight: .bold))
                            .foregroundStyle(themeManager.colors.highlight)
                        Text("\(specials.count) tập")
                            .font(ThemeFont.body(size: 12))
                            .foregroundStyle(ThemeColor.textMuted)
                    }

                    Spacer()

                    Image(systemName: AppIcon.chevronDown)
                        .font(ThemeFont.body(size: 14, weight: .medium))
                        .foregroundStyle(ThemeColor.textMuted)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .animation(DesignTokens.Animation.standard, value: isExpanded)
                }
                .padding(DesignTokens.Spacing.lg)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 0) {
                    Divider()
                        .overlay(themeManager.colors.highlight.opacity(0.2))

                    if specials.isEmpty {
                        Text("Chưa có tập đặc biệt.")
                            .font(ThemeFont.body(size: 14))
                            .foregroundStyle(ThemeColor.textMuted)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 32)
                    } else {
                        LazyVGrid(columns: episodeColumns, spacing: 10) {
                            ForEach(specials, id: \.id) { ep in
                                episodeCard(ep)
                            }
                        }
                        .padding(DesignTokens.Spacing.lg)
                    }
                }
                .transition(.opacity)
            }
        }
        .background(ThemeColor.textPrimary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [6]))
                .foregroundStyle(themeManager.colors.highlight.opacity(0.3))
        )
        .animation(DesignTokens.Animation.standard, value: isExpanded)
    }

    // MARK: - Skeletons & Empty

    private var episodeSkeletonGrid: some View {
        return LazyVGrid(columns: episodeColumns, spacing: 10) {
            ForEach(0..<6, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 10)
                    .fill(ThemeColor.textPrimary.opacity(0.06))
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .overlay {
                        ProgressView()
                    }
            }
        }
        .padding(DesignTokens.Spacing.lg)
    }

    private var emptyState: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Image(systemName: AppIcon.film)
                .font(ThemeFont.display(size: 36))
                .foregroundStyle(ThemeColor.textMuted)
            Text("Chưa có thông tin tập phim.")
                .font(ThemeFont.body(size: 14))
                .foregroundStyle(ThemeColor.textMuted)
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

    // Episode load error state (#47)
    @ViewBuilder
    private var episodeLoadErrorState: some View {
        if let error = viewModel.episodeLoadError {
            VStack(spacing: DesignTokens.Spacing.md) {
                Image(systemName: AppIcon.exclamationmarkTriangle)
                    .font(ThemeFont.display(size: 24))
                    .foregroundStyle(ThemeColor.textMuted)
                Text(error)
                    .font(ThemeFont.body(size: 13))
                    .foregroundStyle(ThemeColor.textMuted)
                    .multilineTextAlignment(.center)
                Button {
                    viewModel.episodeLoadError = nil
                    if let season = viewModel.expandedSeason {
                        // Specials use -1 in the UI but season 0 in the API; map it,
                        // and use effectiveSlug so retry works when slug is nil.
                        let apiSeason = season == -1 ? 0 : season
                        Task { await viewModel.loadEpisodes(
                            slug: viewModel.content?.effectiveSlug ?? "",
                            seasonNumber: apiSeason
                        )}
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: AppIcon.arrowClockwise)
                            .font(ThemeFont.body(size: 11))
                        Text("Thử lại")
                            .font(ThemeFont.body(size: 12, weight: .bold))
                    }
                    .foregroundStyle(ThemeColor.textPrimary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(ThemeColor.textPrimary.opacity(0.08))
                    .clipShape(Capsule())
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
        }
    }

    // MARK: - Helpers

    /// Format date using shared DateFormatting (#35).
    private func formatShortDate(_ dateString: String) -> String {
        DateFormatting.formatShort(dateString)
    }
}
