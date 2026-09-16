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

    // Episode range selection
    var activeRange: (from: Int, to: Int) = (1, 100)
    var totalSeasonEpisodes: Int {
        activeSeason?.episodeCount ?? content?.episodeCount ?? 0
    }

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

    /// Bumped whenever the effective playback source identity changes (server,
    /// episode or season). PlayerPageView observes THIS — not the URL string — so
    /// switching between two servers that happen to share the same stream URL
    /// (mirror/CDN duplicates) still reloads the player and failover works.
    private(set) var sourceVersion: Int = 0
    private func bumpSource() { sourceVersion &+= 1 }

    /// Resolve a server's effective stream URL (HLS preferred, else embed/MP4).
    private func sourceURL(for server: StreamingLink) -> String {
        let m3u8 = server.linkM3u8 ?? ""
        return m3u8.isEmpty ? (server.linkEmbed ?? "") : m3u8
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
        guard let server = activeServer else { return "" }
        return sourceURL(for: server)
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

    /// Seasons sorted by number — used for cross-season adjacency.
    private var sortedSeasons: [Season] {
        seasons.sorted { ($0.seasonNumber ?? 0) < ($1.seasonNumber ?? 0) }
    }

    /// Whether a season is a valid navigation target — skip seasons KNOWN to be
    /// empty (episodeCount == 0). A nil count means "unknown" → allow (don't drop a
    /// real season over missing metadata). Prevents rolling into an episode-less
    /// season (which would open an unplayable, empty player).
    private func seasonHasEpisodes(_ season: Season) -> Bool { (season.episodeCount ?? 1) > 0 }

    /// The next non-empty season after the active one (nil if none).
    var nextSeason: Season? {
        guard let active = activeSeason,
              let idx = sortedSeasons.firstIndex(where: { $0.id == active.id }) else { return nil }
        return sortedSeasons[(idx + 1)...].first(where: seasonHasEpisodes)
    }

    /// The previous non-empty season before the active one (nil if none).
    var previousSeason: Season? {
        guard let active = activeSeason,
              let idx = sortedSeasons.firstIndex(where: { $0.id == active.id }) else { return nil }
        return sortedSeasons[..<idx].last(where: seasonHasEpisodes)
    }

    /// True if there is a next episode in this chunk, another chunk in this season, or a following season.
    var hasNextEpisode: Bool {
        if nextEpisode != nil { return true }
        let currentNum = currentEpisode?.episodeNumber ?? activeRange.to
        if currentNum < totalSeasonEpisodes { return true }
        return nextSeason != nil
    }

    /// True if there is a previous episode in this chunk, a preceding chunk in this season, or a preceding season.
    var hasPreviousEpisode: Bool {
        if previousEpisode != nil { return true }
        let currentNum = currentEpisode?.episodeNumber ?? activeRange.from
        if currentNum > 1 { return true }
        return previousSeason != nil
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
                bumpSource()   // trigger the initial player load for movies
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

                // Compute chunk range if episodeNumber is specified
                var initialFrom = 1
                var initialTo = 100
                if let epNum = episodeNumber, epNum > 0 {
                    initialFrom = ((epNum - 1) / 100) * 100 + 1
                    initialTo = initialFrom + 99
                }
                activeRange = (initialFrom, initialTo)

                // Fetch episodes for active season
                await loadEpisodes(slug: slug, episodeId: episodeId, episodeNumber: episodeNumber, fromEpisode: initialFrom, toEpisode: initialTo)
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

    /// Switch to a different episode range (e.g. 101 to 200) for the active season.
    func changeRange(to from: Int, to: Int, slug: String) async {
        activeRange = (from, to)
        await loadEpisodes(slug: slug, fromEpisode: from, toEpisode: to)
    }

    /// Load episodes for the active season and range.
    /// - Parameter selectLast: when true, selects the LAST episode after loading
    ///   (used when rolling back into the previous season or range).
    func loadEpisodes(
        slug: String,
        episodeId: String? = nil,
        episodeNumber: Int? = nil,
        selectLast: Bool = false,
        fromEpisode: Int? = nil,
        toEpisode: Int? = nil
    ) async {
        guard let season = activeSeason else { return }
        let seasonNum = season.seasonNumber ?? 1
        let fromEp = fromEpisode ?? activeRange.from
        let toEp = toEpisode ?? activeRange.to
        activeRange = (fromEp, toEp)

        func applySelection() {
            if selectLast, let last = seasonEpisodes.last {
                setCurrentEpisode(last)
            } else {
                selectEpisode(episodeId: episodeId, episodeNumber: episodeNumber)
            }
        }

        let cacheKey = "\(activeSeasonId)_\(fromEp)_\(toEp)"
        // Check cache
        if let cached = episodesCache[cacheKey] {
            seasonEpisodes = cached
            applySelection()
            return
        }

        isEpisodesLoading = true
        do {
            let episodes = try await apiClient.fetchSeriesEpisodes(
                slug: slug,
                seasonNumber: seasonNum,
                fromEpisode: fromEp,
                toEpisode: toEp,
                episodeNumber: nil
            )
            episodesCache[cacheKey] = episodes
            seasonEpisodes = episodes
            applySelection()
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
        bumpSource()
    }

    /// Navigate to a specific episode by ID.
    func goToEpisode(_ episodeId: String) {
        guard let ep = seasonEpisodes.first(where: { $0.id == episodeId }) else { return }
        setCurrentEpisode(ep)
    }

    /// Go to the next episode, rolling into the next chunk or season if needed.
    func goToNextEpisode(slug: String) async {
        if let next = nextEpisode {
            setCurrentEpisode(next)
            return
        }
        let currentNum = currentEpisode?.episodeNumber ?? activeRange.to
        if currentNum < totalSeasonEpisodes {
            let nextFrom = activeRange.to + 1
            let nextTo = min(nextFrom + 99, totalSeasonEpisodes)
            await loadEpisodes(slug: slug, episodeNumber: nextFrom, fromEpisode: nextFrom, toEpisode: nextTo)
            return
        }
        guard let next = nextSeason else { return }
        clearSeasonState(activeSeasonId: next.id)
        activeRange = (1, 100)
        await loadEpisodes(slug: slug, fromEpisode: 1, toEpisode: 100)
    }

    /// Go to the previous episode, rolling back into previous chunk or season if needed.
    func goToPreviousEpisode(slug: String) async {
        if let prev = previousEpisode {
            setCurrentEpisode(prev)
            return
        }
        let currentNum = currentEpisode?.episodeNumber ?? activeRange.from
        if currentNum > 1 {
            let prevTo = activeRange.from - 1
            let prevFrom = max(1, prevTo - 99)
            await loadEpisodes(slug: slug, selectLast: true, fromEpisode: prevFrom, toEpisode: prevTo)
            return
        }
        guard let prev = previousSeason else { return }
        clearSeasonState(activeSeasonId: prev.id)
        let prevCount = prev.episodeCount ?? 100
        let prevFrom = max(1, ((prevCount - 1) / 100) * 100 + 1)
        activeRange = (prevFrom, prevCount)
        await loadEpisodes(slug: slug, selectLast: true, fromEpisode: prevFrom, toEpisode: prevCount)
    }

    // MARK: - Change Season

    func changeSeason(to seasonId: String, slug: String) async {
        guard seasonId != activeSeasonId else { return }
        clearSeasonState(activeSeasonId: seasonId)
        activeRange = (1, 100)
        await loadEpisodes(slug: slug, fromEpisode: 1, toEpisode: 100)
    }

    /// Reset per-season state so the UI never shows the previous season's
    /// episode/servers/subtitles while the new season loads asynchronously.
    private func clearSeasonState(activeSeasonId newSeasonId: String) {
        activeSeasonId = newSeasonId
        activeServerIndex = 0
        currentEpisode = nil
        seasonEpisodes = []
        servers = []
        subtitles = []
    }

    // MARK: - Server Selection

    func selectServer(at index: Int) {
        guard index >= 0 && index < servers.count else { return }
        guard index != activeServerIndex else { return }
        activeServerIndex = index
        bumpSource()
    }

    /// Try the next server with a DIFFERENT stream URL (called on player error).
    /// Skips mirror servers that resolve to the same URL as the one that just
    /// failed, so automatic failover actually changes the source.
    func tryNextServer() {
        let failedURL = videoSource
        var idx = activeServerIndex + 1
        while idx < servers.count {
            let candidate = sourceURL(for: servers[idx])
            if !candidate.isEmpty && candidate != failedURL {
                activeServerIndex = idx
                bumpSource()
                return
            }
            idx += 1
        }
        // No distinct server remains — the error stays surfaced to the user.
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
