//
//  HomeViewModel.swift
//  MovieStreamingApple
//
//  ViewModel for the Home screen. Mirrors `useHomeContents()` hook from the website.
//  Eagerly fetches all datasets needed for tabs and sections using TaskGroup.
//

import Foundation
import os

private let logger = Logger(subsystem: "com.d9042n.moviestreaming", category: "HomeViewModel")

@Observable
@MainActor
final class HomeViewModel {
    // MARK: - Published State

    var heroContents: [Content] = []

    // Theater (Movies) — eagerly loaded per tab
    var theaterPopular: [Content] = []
    var theaterComingSoon: [Content] = []
    var theaterTopRated: [Content] = []
    var theaterLatest: [Content] = []

    // TV (Series) — eagerly loaded per tab
    var tvPopular: [Content] = []
    var tvComingSoon: [Content] = []
    var tvTopRated: [Content] = []
    var tvLatest: [Content] = []


    // Genre Carousel
    var genres: [Genre] = []

    // Blog
    var blogPosts: [BlogPost] = []

    // Curated Collections
    var collections: [ContentCollection] = []

    // UI State
    var isLoading = false
    var error: String?

    // Active tab selections
    var activeMovieTab: ContentTab = .popular
    var activeSeriesTab: ContentTab = .popular

    // MARK: - Cached Computed Properties (#30)

    /// Cached visible genres — updated when `genres` changes.
    private(set) var visibleGenres: [Genre] = []

    // MARK: - Dependencies

    private let apiClient: APIClientProtocol

    init(apiClient: APIClientProtocol = APIClient()) {
        self.apiClient = apiClient
    }

    // MARK: - Data Accessors (mirrors getTabData from website)

    /// Returns movies for the currently selected tab.
    var currentMovies: [Content] {
        movieData(for: activeMovieTab)
    }

    /// Returns series for the currently selected tab.
    var currentSeries: [Content] {
        seriesData(for: activeSeriesTab)
    }

    func movieData(for tab: ContentTab) -> [Content] {
        switch tab {
        case .popular: return theaterPopular
        case .comingSoon: return theaterComingSoon
        case .topRated: return theaterTopRated
        case .latest: return theaterLatest
        }
    }

    func seriesData(for tab: ContentTab) -> [Content] {
        switch tab {
        case .popular: return tvPopular
        case .comingSoon: return tvComingSoon
        case .topRated: return tvTopRated
        case .latest: return tvLatest
        }
    }

    /// Recompute cached visibleGenres from raw genres.
    private func updateVisibleGenres() {
        visibleGenres = Array(
            genres
                .filter { ($0.contentCount ?? 0) > 10 }
                .sorted { ($0.contentCount ?? 0) > ($1.contentCount ?? 0) }
                .prefix(20)
        )
    }

    // MARK: - Fetch All Data

    /// Mirrors `fetchAll()` from `useHomeContents.ts`.
    /// Uses parallel requests with individual error handling (#2)
    /// so one failing request doesn't block all sections.
    func fetchAll() async {
        // #47: Guard against re-entry during rapid pull-to-refresh
        guard !isLoading else { return }

        isLoading = true
        error = nil
        // #1: defer guarantees cleanup on all exit paths
        defer { isLoading = false }

        // Fire all requests in parallel — each wrapped to handle errors independently (#2)
        async let tPopResult = safeResult { try await self.apiClient.fetchContents(params: "type=movie&sort_by=views&sort_order=desc&page_size=10") }
        async let tComingResult = safeResult { try await self.apiClient.fetchContents(params: "type=movie&status=trailer&sort_by=release_date&sort_order=desc&page_size=10") }
        async let tTopResult = safeResult { try await self.apiClient.fetchContents(params: "type=movie&sort_by=rating&sort_order=desc&page_size=10") }
        async let tLatestResult = safeResult { try await self.apiClient.fetchContents(params: "type=movie&sort_by=latest_episode&sort_order=desc&page_size=10") }

        async let tvPopResult = safeResult { try await self.apiClient.fetchContents(params: "type=series&sort_by=views&sort_order=desc&page_size=10") }
        async let tvComingResult = safeResult { try await self.apiClient.fetchContents(params: "type=series&status=trailer&sort_by=release_date&sort_order=desc&page_size=10") }
        async let tvTopResult = safeResult { try await self.apiClient.fetchContents(params: "type=series&sort_by=rating&sort_order=desc&page_size=10") }
        async let tvLatResult = safeResult { try await self.apiClient.fetchContents(params: "type=series&sort_by=latest_episode&sort_order=desc&page_size=10") }

        async let genreListResult = safeResult { try await self.apiClient.fetchGenres() }
        async let blogsResult = safeResult { try await self.apiClient.fetchBlogPosts() }
        async let collectionListResult = safeResult { try await self.apiClient.fetchCollections() }

        // Await all results — each is optional, nil on failure
        let (tPop, tComing, tTop, tLatest) = await (tPopResult, tComingResult, tTopResult, tLatestResult)
        let (tvPop, tvComing, tvTop, tvLat) = await (tvPopResult, tvComingResult, tvTopResult, tvLatResult)

        let fetchedGenres = await genreListResult
        let fetchedBlogs = await blogsResult
        let fetchedCollections = await collectionListResult

        // Count failures to detect total failure
        var failCount = 0
        let totalRequests = 11

        // Assign results — each section succeeds independently
        if let tPop { theaterPopular = tPop.data } else { failCount += 1 }
        if let tComing { theaterComingSoon = tComing.data } else { failCount += 1 }
        if let tTop { theaterTopRated = tTop.data } else { failCount += 1 }
        if let tLatest { theaterLatest = tLatest.data } else { failCount += 1 }

        if let tvPop { tvPopular = tvPop.data } else { failCount += 1 }
        if let tvComing { tvComingSoon = tvComing.data } else { failCount += 1 }
        if let tvTop { tvTopRated = tvTop.data } else { failCount += 1 }
        if let tvLat { tvLatest = tvLat.data } else { failCount += 1 }

        if let fetchedGenres { genres = fetchedGenres } else { failCount += 1 }
        if let fetchedBlogs { blogPosts = fetchedBlogs } else { failCount += 1 }
        if let fetchedCollections { collections = fetchedCollections.sorted { $0.sortOrder < $1.sortOrder } } else { failCount += 1 }

        // Build hero slider from trending collections (interleaved movie + TV)
        let heroCollections = fetchedCollections ?? collections
        let trendingMovieCollection = heroCollections.first { $0.slug == "trending-day" }
        let trendingTvCollection = heroCollections.first { $0.slug == "trending-tv-day" }
        let heroMovies = trendingMovieCollection?.contents ?? []
        let heroTv = trendingTvCollection?.contents ?? []

        var interleaved: [Content] = []
        var seenIds: Set<String> = []
        let maxLen = max(heroMovies.count, heroTv.count)
        for i in 0..<maxLen {
            if i < heroMovies.count, !seenIds.contains(heroMovies[i].id) {
                interleaved.append(heroMovies[i])
                seenIds.insert(heroMovies[i].id)
            }
            if i < heroTv.count, !seenIds.contains(heroTv[i].id) {
                interleaved.append(heroTv[i])
                seenIds.insert(heroTv[i].id)
            }
        }

        heroContents = Array(interleaved.prefix(10))

        // Update cached visible genres
        updateVisibleGenres()

        // Set error only if ALL requests failed
        if failCount == totalRequests {
            error = "Không thể kết nối đến máy chủ"
        } else if failCount > 0 {
            logger.warning("Home: \(failCount)/\(totalRequests) requests failed")
        }
    }

    // MARK: - Safe Fetch Helper (#2)

    /// Wraps an async throwing operation, catching errors and returning nil instead of throwing.
    /// Preserves parallelism when used with `async let`.
    private func safeResult<T: Sendable>(_ operation: @Sendable () async throws -> T) async -> T? {
        do {
            return try await operation()
        } catch {
            logger.error("Request failed: \(error.localizedDescription)")
            return nil
        }
    }
}
