//
//  PlayerEpisodeList.swift
//  MovieStreamingApple
//
//  Episode list for series in the Watch page.
//  Shows season selector + scrollable episode list with thumbnails.
//

import SwiftUI

struct PlayerEpisodeList: View {
    let seasons: [Season]
    let activeSeasonId: String
    let episodes: [Episode]
    let currentEpisodeId: String?
    let posterFallback: String?
    let isLoading: Bool
    /// Whether to show the built-in header. Set `false` when used inside
    /// the toggle-button pattern which already provides its own header.
    var showHeader: Bool = true

    var onSeasonChange: (String) -> Void
    var onEpisodeTap: (String) -> Void

    @State private var showSeasonPicker = false

    @Environment(\.themeManager) private var themeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header (hidden when parent provides its own)
            if showHeader {
                header
                Divider().background(.gray.opacity(0.3))
            }

            // Episode list
            if isLoading {
                episodeSkeleton
            } else if episodes.isEmpty {
                emptyState
            } else {
                episodeList
            }
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: AppIcon.listBulletBelowRectangle)
                    .font(ThemeFont.body(size: 11))
                    .foregroundStyle(themeManager.colors.link)
                Text("Danh sách tập")
                    .font(ThemeFont.display(size: 14, weight: .bold))
            }

            Spacer()

            // Season selector
            if seasons.count > 1 {
                Menu {
                    ForEach(seasons) { season in
                        Button {
                            onSeasonChange(season.id)
                        } label: {
                            HStack {
                                Text(season.title)
                                if let count = season.episodeCount {
                                    Text("(\(count) tập)")
                                        .foregroundStyle(ThemeColor.textMuted)
                                }
                                if season.id == activeSeasonId {
                                    Image(systemName: AppIcon.checkmark)
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(seasons.first { $0.id == activeSeasonId }?.title ?? "Mùa")
                            .font(ThemeFont.body(size: 12, weight: .bold))
                        Image(systemName: AppIcon.chevronDown)
                            .font(ThemeFont.body(size: 11))
                    }
                    .foregroundStyle(ThemeColor.textPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(themeManager.colors.bgCard, in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: - Episode List

    private var episodeList: some View {
        // PERF-03: Auto-scroll to currently playing episode
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(episodes) { episode in
                        episodeRow(episode)
                            .id(episode.id)
                        if episode.id != episodes.last?.id {
                            Divider().background(.gray.opacity(0.2)).padding(.leading, 14)
                        }
                    }
                }
            }
            .frame(maxHeight: 400)
            // Auto-scroll to the active episode. `.task(id:)` is tied to the view
            // lifecycle (auto-cancelled if it disappears) and re-runs when the
            // active episode changes — replacing a fixed asyncAfter that could fire
            // after the view was gone or before layout completed.
            .task(id: currentEpisodeId) {
                guard let activeId = currentEpisodeId else { return }
                try? await Task.sleep(for: .milliseconds(250))
                guard !Task.isCancelled else { return }
                withAnimation(.easeInOut(duration: 0.3)) {
                    proxy.scrollTo(activeId, anchor: .center)
                }
            }
        }
    }

    @ViewBuilder
    private func episodeRow(_ episode: Episode) -> some View {
        let isActive = episode.id == currentEpisodeId

        Button {
            onEpisodeTap(episode.id)
        } label: {
            HStack(spacing: 10) {
                // Thumbnail
                ZStack {
                    AsyncImage(url: URL(string: episode.thumbnailUrl ?? posterFallback ?? "")) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 110, height: 62, alignment: .top)
                        default:
                            Rectangle().fill(.gray.opacity(0.2))
                                .overlay {
                                    Image(systemName: AppIcon.film)
                                        .foregroundStyle(ThemeColor.textMuted)
                                }
                        }
                    }
                    .frame(width: 110, height: 62)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    if isActive {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.black.opacity(0.5))
                            .frame(width: 110, height: 62)
                            .overlay {
                                Image(systemName: AppIcon.playFill)
                                    .font(ThemeFont.display(size: 20, weight: .semibold))
                                    .foregroundStyle(ThemeColor.textPrimary)
                            }
                    }

                    // Duration badge
                    if let duration = episode.formattedDuration {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Text(duration)
                                    .font(ThemeFont.body(size: 9, weight: .medium))
                                    .foregroundStyle(ThemeColor.textPrimary)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 3))
                            }
                        }
                        .frame(width: 110, height: 62)
                        .padding(3)
                    }
                }

                // Info
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("Tập \(episode.episodeNumber ?? 0)")
                            .font(ThemeFont.display(size: 11, weight: .bold))
                            .foregroundStyle(isActive ? themeManager.colors.brand : ThemeColor.textMuted)
                            .textCase(.uppercase)

                        if episode.isRecent {
                            HStack(spacing: 2) {
                                Circle()
                                    .fill(themeManager.colors.highlight)
                                    .frame(width: 4, height: 4)
                                Text("Mới")
                                    .font(ThemeFont.display(size: 8, weight: .bold))
                                    .foregroundStyle(themeManager.colors.highlight)
                            }
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(themeManager.colors.highlight.opacity(0.1), in: Capsule())
                        }
                    }

                    if let title = episode.title {
                        Text(title)
                            .font(ThemeFont.body(size: 12, weight: .bold))
                            .foregroundStyle(isActive ? themeManager.colors.textPrimary : ThemeColor.textMuted)
                            .lineLimit(2)
                    }

                    if let airDate = episode.airDate {
                        Text(formattedDate(airDate))
                            .font(ThemeFont.body(size: 10))
                            .foregroundStyle(ThemeColor.textMuted)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(isActive ? themeManager.colors.brand.opacity(0.08) : .clear)
        }
        .buttonStyle(.plain)
        // A11Y-04: Announce active episode to VoiceOver
        .accessibilityHint(isActive ? "Đang phát" : "")
    }

    // MARK: - Empty & Loading

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: AppIcon.film)
                .font(ThemeFont.display(size: 28, weight: .bold))
                .foregroundStyle(ThemeColor.textMuted)
            Text("Chưa có tập phim cho mùa này")
                .font(ThemeFont.body(size: 12))
                .foregroundStyle(ThemeColor.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var episodeSkeleton: some View {
        LazyVStack(spacing: 0) {
            ForEach(0..<5, id: \.self) { _ in
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.gray.opacity(0.15))
                        .frame(width: 110, height: 62)

                    VStack(alignment: .leading, spacing: 6) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(.gray.opacity(0.15))
                            .frame(width: 50, height: 10)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(.gray.opacity(0.1))
                            .frame(height: 12)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(.gray.opacity(0.08))
                            .frame(width: 80, height: 8)
                    }

                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
        }
        .redacted(reason: .placeholder)
    }

    // MARK: - Helpers

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f
    }()

    private static let displayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.locale = Locale(identifier: "vi_VN")
        return f
    }()

    private func formattedDate(_ dateStr: String) -> String {
        guard let date = Self.isoFormatter.date(from: dateStr) else { return dateStr }
        return Self.displayFormatter.string(from: date)
    }
}
