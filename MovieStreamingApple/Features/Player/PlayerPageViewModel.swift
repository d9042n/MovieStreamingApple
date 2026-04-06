//
//  PlayerPageViewModel.swift
//  MovieStreamingApple
//
//  Data and state management for the Watch page.
//  Mirrors useWatchPage.ts: fetches content, episodes, credits, related, media.
//  Handles server selection, episode navigation, and view tracking.
//

import Foundation
import os

private let logger = Logger(subsystem: "com.d9042n.moviestreaming", category: "PlayerPageViewModel")

@Observable
@MainActor
final class PlayerPageViewModel {

    // MARK: - Dependencies

    private let apiClient: APIClientProtocol

    // MARK: - Content State

    var content: Content?
    var watchDetail: WatchDetailResponse?
    var isLoading = true
    var error: String?

    // MARK: - Series State

    var seasons: [Season] = []
    var activeSeasonId: String = ""
    var seasonEpisodes: [Episode] = []
    var isEpisodesLoading = false
    private var episodesCache: [String: [Episode]] = [:]

    // MARK: - Current Episode (series)

    var currentEpisode: Episode?

    // MARK: - Servers

    var servers: [StreamingLink] = []
    var activeServerIndex: Int = 0
    var activeServer: StreamingLink? {
        guard !servers.isEmpty else { return nil }
        let idx = min(activeServerIndex, servers.count - 1)
        return servers[idx]
    }

    // MARK: - Subtitles

    var subtitles: [SubtitleTrack] = []

    // MARK: - Credits

    var actors: [CastMember] = []
    var directors: [Person] = []

    // MARK: - Related & Media

    var relatedContents: [Content] = []
    var media: [MediaItem] = []

    // MARK: - View Tracking

    private var viewTracked = false

    // MARK: - Derived

    var isSeries: Bool { content?.type == .series }

    /// Whether the content is vertical format (9:16 short drama, like TikTok/YouTube Shorts).
    /// Detected via genre slug "phim-ngan-man-hinh-doc" from the API.
    var isVerticalContent: Bool {
        content?.genres?.contains {
            switch $0 {
            case .object(let genre):
                return genre.slug == "phim-ngan-man-hinh-doc"
            case .string(let name):
                return name == "Phim Ngắn Màn Hình Dọc"
            }
        } ?? false
    }

    /// Unified video source: prefers HLS (linkM3u8), falls back to direct URL (linkEmbed).
    /// Both formats are played through the native AVPlayer for full feature parity.
    var videoSource: String {
        let m3u8 = activeServer?.linkM3u8 ?? ""
        if !m3u8.isEmpty { return m3u8 }
        // Fallback: linkEmbed may contain a direct MP4 URL
        return activeServer?.linkEmbed ?? ""
    }

    var posterUrl: String {
        if isSeries {
            return currentEpisode?.thumbnailUrl ?? content?.backdropUrl ?? content?.posterUrl ?? ""
        }
        return content?.backdropUrl ?? content?.posterUrl ?? ""
    }

    var displayTitle: String {
        if isSeries, let ep = currentEpisode {
            return "\(content?.title ?? "") — Tập \(ep.episodeNumber ?? 0)"
        }
        return content?.title ?? ""
    }

    var displayDescription: String {
        let raw: String
        if isSeries, let ep = currentEpisode {
            raw = ep.description ?? content?.description ?? ""
        } else {
            raw = content?.description ?? ""
        }
        // Strip HTML tags
        return raw.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression).trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Episode Navigation

    var nextEpisode: Episode? {
        guard isSeries, let current = currentEpisode else { return nil }
        guard let idx = seasonEpisodes.firstIndex(where: { $0.id == current.id }) else { return nil }
        let nextIdx = idx + 1
        guard nextIdx < seasonEpisodes.count else { return nil }
        return seasonEpisodes[nextIdx]
    }

    var previousEpisode: Episode? {
        guard isSeries, let current = currentEpisode else { return nil }
        guard let idx = seasonEpisodes.firstIndex(where: { $0.id == current.id }), idx > 0 else { return nil }
        return seasonEpisodes[idx - 1]
    }

    /// Active season object.
    var activeSeason: Season? {
        seasons.first { $0.id == activeSeasonId }
    }

    // MARK: - Init

    init(apiClient: APIClientProtocol = APIClient()) {
        self.apiClient = apiClient
    }

    // MARK: - Load All Data

    /// Main entry point: loads content + extras in parallel.
    func loadContent(slug: String, type: ContentType, episodeId: String? = nil, seasonNumber: Int? = nil, episodeNumber: Int? = nil) async {
        isLoading = true
        error = nil

        do {
            // 1. Fetch content detail
            let detail = try await apiClient.fetchWatchDetail(slug: slug, type: type)
            watchDetail = detail
            content = detail.asContent

            // 2. Handle streaming for movies
            if type == .movie {
                if let links = detail.streamingLinks, !links.isEmpty {
                    servers = links
                    subtitles = detail.subtitles ?? []
                } else {
                    servers = []
                    subtitles = []
                }
            }

            // 3. Handle seasons for series
            if type == .series, let detailSeasons = detail.seasons, !detailSeasons.isEmpty {
                let sorted = detailSeasons.sorted { ($0.seasonNumber ?? 0) < ($1.seasonNumber ?? 0) }
                seasons = sorted

                // Auto-select season
                if let seasonNum = seasonNumber,
                   let match = sorted.first(where: { $0.seasonNumber == seasonNum }) {
                    activeSeasonId = match.id
                } else if activeSeasonId.isEmpty {
                    activeSeasonId = sorted.first?.id ?? ""
                }

                // Fetch episodes for active season
                await loadEpisodes(slug: slug, episodeId: episodeId, episodeNumber: episodeNumber)
            }

            // 4. Fetch extras in parallel
            async let _creditsTask: Void = loadCredits(slug: slug, type: type)
            async let _relatedTask: Void = loadRelated(slug: slug, type: type)
            async let _mediaTask: Void = loadMedia(slug: slug, type: type)
            _ = await (_creditsTask, _relatedTask, _mediaTask)

            // 5. Track view
            trackViewIfNeeded()

        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Episodes

    /// Load episodes for the active season.
    func loadEpisodes(slug: String, episodeId: String? = nil, episodeNumber: Int? = nil) async {
        guard let season = activeSeason else { return }
        let seasonNum = season.seasonNumber ?? 1

        // Check cache
        if let cached = episodesCache[activeSeasonId] {
            seasonEpisodes = cached
            selectEpisode(episodeId: episodeId, episodeNumber: episodeNumber)
            return
        }

        isEpisodesLoading = true
        do {
            let episodes = try await apiClient.fetchSeriesEpisodes(slug: slug, seasonNumber: seasonNum)
            episodesCache[activeSeasonId] = episodes
            seasonEpisodes = episodes
            selectEpisode(episodeId: episodeId, episodeNumber: episodeNumber)
        } catch {
            logger.error("Episodes fetch failed: \(error.localizedDescription)")
        }
        isEpisodesLoading = false
    }

    /// Select a specific episode and update servers/subtitles.
    private func selectEpisode(episodeId: String? = nil, episodeNumber: Int? = nil) {
        // Priority 1: explicit episode ID
        if let id = episodeId, let ep = seasonEpisodes.first(where: { $0.id == id }) {
            setCurrentEpisode(ep)
            return
        }

        // Priority 2: episode number
        if let num = episodeNumber, let ep = seasonEpisodes.first(where: { $0.episodeNumber == num }) {
            setCurrentEpisode(ep)
            return
        }

        // Fallback: first episode
        if let first = seasonEpisodes.first {
            setCurrentEpisode(first)
        }
    }

    /// Set the current episode and update servers/subtitles.
    func setCurrentEpisode(_ episode: Episode) {
        currentEpisode = episode
        servers = episode.servers ?? []
        subtitles = episode.subtitles ?? []
        activeServerIndex = 0

        // Reset view tracking so each episode gets its own view count
        viewTracked = false
        trackViewIfNeeded()
    }

    /// Navigate to a specific episode by ID.
    func goToEpisode(_ episodeId: String) {
        guard let ep = seasonEpisodes.first(where: { $0.id == episodeId }) else { return }
        setCurrentEpisode(ep)
    }

    /// Go to the next episode.
    func goToNextEpisode() {
        guard let next = nextEpisode else { return }
        setCurrentEpisode(next)
    }

    /// Go to the previous episode.
    func goToPreviousEpisode() {
        guard let prev = previousEpisode else { return }
        setCurrentEpisode(prev)
    }

    // MARK: - Change Season

    func changeSeason(to seasonId: String, slug: String) async {
        activeSeasonId = seasonId
        activeServerIndex = 0
        await loadEpisodes(slug: slug)
    }

    // MARK: - Server Selection

    func selectServer(at index: Int) {
        guard index >= 0 && index < servers.count else { return }
        activeServerIndex = index
    }

    /// Try the next server (called on player error).
    func tryNextServer() {
        let nextIdx = activeServerIndex + 1
        if nextIdx < servers.count {
            activeServerIndex = nextIdx
        }
    }

    // MARK: - Credits

    private func loadCredits(slug: String, type: ContentType) async {
        do {
            let credits = try await apiClient.fetchCredits(slug: slug, type: type)
            actors = credits.cast ?? []
            directors = (credits.crew?["directing"] ?? []).map {
                Person(id: $0.id, name: $0.name, slug: $0.slug, photoUrl: $0.photoUrl, department: $0.department, characterName: nil)
            }
        } catch {
            logger.error("Credits fetch failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Related

    private func loadRelated(slug: String, type: ContentType) async {
        do {
            relatedContents = try await apiClient.fetchRelatedContents(slug: slug, type: type)
        } catch {
            logger.error("Related fetch failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Media

    private func loadMedia(slug: String, type: ContentType) async {
        do {
            media = try await apiClient.fetchMedia(slug: slug, type: type)
        } catch {
            logger.error("Media fetch failed: \(error.localizedDescription)")
        }
    }

    // MARK: - View Tracking

    private func trackViewIfNeeded() {
        guard let id = content?.id, !viewTracked else { return }
        viewTracked = true
        Task {
            await apiClient.trackView(contentId: id)
        }
    }
}
