//
//  ContentDetailViewModel.swift
//  MovieStreamingApple
//
//  ViewModel for the Content Detail screen.
//  Mirrors `useContentDetail()` hook from the website.
//  Fetches content detail, credits, related, seasons, episodes, and media in parallel.
//

import Foundation

/// Tab options for the content detail page.
enum DetailTab: String, CaseIterable, Identifiable, Sendable {
    case overview
    case episodes
    case cast
    case reviews

    var id: String { rawValue }

    var label: String {
        switch self {
        case .overview: return "Tổng Quan"
        case .episodes: return "Tập Phim"
        case .cast: return "Diễn Viên"
        case .reviews: return "Đánh Giá"
        }
    }
}

@Observable
@MainActor
final class ContentDetailViewModel {
    // MARK: - Published State

    var content: Content?
    var seasons: [Season] = []
    var episodesBySeasonMap: [Int: [Episode]] = [:]
    var media: [MediaItem] = []
    var cast: [CastMember] = []
    var crew: [String: [CastMember]] = [:]
    var relatedContents: [Content] = []
    var strippedDescription: String?

    var isLoading = false
    var isLoadingEpisodes = false
    var error: String?
    var episodeLoadError: String?

    // UI State
    var activeTab: DetailTab = .overview
    var expandedSeason: Int?
    var showAllCast = false

    // MARK: - Dependencies

    private let apiClient: APIClientProtocol

    init(apiClient: APIClientProtocol = APIClient()) {
        self.apiClient = apiClient
    }

    // MARK: - Computed Properties

    var isMovie: Bool { content?.type != .series }
    var isSeries: Bool { content?.type == .series }

    /// Tabs available for current content (movies don't have episodes tab).
    /// Note: .reviews removed — feature not yet implemented (hidden for App Store review)
    var availableTabs: [DetailTab] {
        if isSeries {
            return [.overview, .episodes, .cast]
        }
        return [.overview, .cast]
    }

    /// Release year extracted from content.
    var releaseYear: Int? { content?.releaseYear }

    /// Total views from stats or fallback.
    var totalViews: Int {
        content?.stats?.totalViews ?? content?.totalViews ?? 0
    }

    /// Daily views from stats.
    var dailyViews: Int {
        content?.stats?.dailyViews ?? 0
    }

    /// Bookmark count from stats.
    var bookmarkCount: Int {
        content?.stats?.bookmarkCount ?? 0
    }

    /// Rating count from stats or fallback.
    /// Detail API: rating data lives in `stats` object (not top-level like list API)
    var ratingCount: Int {
        content?.stats?.ratingCount ?? content?.ratingCount ?? 0
    }

    /// Average rating from stats or top-level fallback.
    /// Detail API: `averageRating` is inside `stats`, not at top-level.
    /// List API: `averageRating` is at top-level. This covers both cases.
    var averageRating: Double {
        content?.stats?.averageRating ?? content?.averageRating ?? 0
    }

    /// All cast: prefer credits API, fallback to content.topCast.
    var allCast: [CastMember] {
        if !cast.isEmpty { return cast }
        return content?.topCast ?? []
    }

    /// Displayed cast (limited or full).
    var displayedCast: [CastMember] {
        showAllCast ? allCast : Array(allCast.prefix(10))
    }

    /// Directors from crew or content.directors.
    var directors: [Person] {
        if let directing = crew["directing"], !directing.isEmpty {
            return directing.map { Person(id: $0.id, name: $0.name, slug: $0.slug, photoUrl: $0.photoUrl, department: "directing", characterName: nil) }
        }
        return content?.directors ?? []
    }

    /// Backdrops from media gallery.
    var backdrops: [MediaItem] {
        media.filter(\.isBackdrop)
    }

    /// Posters from media gallery.
    var posters: [MediaItem] {
        media.filter(\.isPoster)
    }

    /// All gallery items (backdrops + posters).
    var allGalleryItems: [MediaItem] {
        backdrops + posters
    }

    /// Status info for display.
    var statusInfo: (label: String, color: StatusColor)? {
        guard let status = content?.status else { return nil }
        switch status {
        case "ongoing": return ("Đang Chiếu", .green)
        case "completed": return ("Hoàn Tất", .blue)
        case "trailer": return ("Sắp Chiếu", .orange)
        default: return nil
        }
    }

    /// Regular seasons (season number > 0).
    var regularSeasons: [Season] {
        seasons.filter { ($0.seasonNumber ?? 0) > 0 }
    }

    /// Special episodes (season 0 + non-standard from other seasons).
    var specialEpisodes: [Episode] {
        var specials = episodesBySeasonMap[0] ?? []
        for (seasonNum, episodes) in episodesBySeasonMap where seasonNum != 0 {
            specials.append(contentsOf: episodes.filter { !$0.isStandard })
        }
        return specials
    }

    /// Whether special episodes section should be shown.
    var hasSpecialEpisodes: Bool {
        seasons.contains { ($0.seasonNumber ?? -1) == 0 } || !specialEpisodes.isEmpty
    }

    // MARK: - Fetch All Data

    /// Main load function — mirrors websites's useContentDetail + extra fetches.
    func loadContent(slug: String, type: ContentType) async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            // 1. Fetch content detail first
            let fetchedContent = try await apiClient.fetchContentDetail(slug: slug, type: type)
            content = fetchedContent

            // Pre-process HTML description off main thread (#3)
            if let desc = fetchedContent.description, !desc.isEmpty {
                strippedDescription = desc
                    .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }

            let resolvedSlug = fetchedContent.slug ?? slug
            let resolvedType = fetchedContent.type ?? type

            // 2. Fetch extras in parallel
            async let creditsResult = apiClient.fetchCredits(slug: resolvedSlug, type: resolvedType)
            async let relatedResult = apiClient.fetchRelatedContents(slug: resolvedSlug, type: resolvedType)
            async let mediaResult = apiClient.fetchMedia(slug: resolvedSlug, type: resolvedType)

            let (credits, related, fetchedMedia) = try await (creditsResult, relatedResult, mediaResult)

            cast = credits.cast ?? []
            crew = credits.crew ?? [:]
            relatedContents = related
            media = fetchedMedia

            // 3. Fetch seasons if series
            if resolvedType == .series {
                let fetchedSeasons = try await apiClient.fetchSeasons(slug: resolvedSlug)
                seasons = fetchedSeasons

                // Auto-expand first season
                if let firstSeason = fetchedSeasons.first {
                    let firstNum = firstSeason.seasonNumber ?? 1
                    expandedSeason = firstNum
                    await loadEpisodes(slug: resolvedSlug, seasonNumber: firstNum)
                }
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Load episodes for a specific season.
    func loadEpisodes(slug: String, seasonNumber: Int) async {
        // Guard: skip invalid season numbers (#7)
        guard seasonNumber >= 0 else { return }
        // Clear the shared error up front (incl. the cache-hit path below) so a
        // previously-failed season doesn't show its error on a healthy cached one.
        episodeLoadError = nil
        // Skip if already loaded
        guard episodesBySeasonMap[seasonNumber] == nil else { return }

        isLoadingEpisodes = true
        do {
            let episodes = try await apiClient.fetchEpisodes(slug: slug, seasonNumber: seasonNumber)
            episodesBySeasonMap[seasonNumber] = episodes
            episodeLoadError = nil
        } catch {
            // Surface error instead of silent failure (#47)
            episodeLoadError = "Không thể tải tập phim. Vui lòng thử lại."
        }
        isLoadingEpisodes = false
    }

    /// Toggle season expansion and load episodes if needed.
    func toggleSeason(_ seasonNumber: Int) async {
        if expandedSeason == seasonNumber {
            expandedSeason = nil
        } else {
            expandedSeason = seasonNumber
            // Use effectiveSlug (falls back to id) so seasons still load when the
            // API returns content with a nil/empty slug — matching loadContent.
            guard let slug = content?.effectiveSlug, !slug.isEmpty else { return } // (#7)
            // Special episodes use season 0 for API, but -1 for UI toggle
            let apiSeason = seasonNumber == -1 ? 0 : seasonNumber
            await loadEpisodes(slug: slug, seasonNumber: apiSeason)
        }
    }

    /// Episodes for a specific season (standard only).
    func standardEpisodes(for seasonNumber: Int) -> [Episode] {
        (episodesBySeasonMap[seasonNumber] ?? []).filter(\.isStandard)
    }
}

// MARK: - Status Color

enum StatusColor: Sendable {
    case green, blue, orange
}
