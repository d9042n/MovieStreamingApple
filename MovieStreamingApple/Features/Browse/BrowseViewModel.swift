//
//  BrowseViewModel.swift
//  MovieStreamingApple
//
//  ViewModel for Browse (Content Directory) page.
//  Mirrors `useContents()` hook from the website.
//  Supports search, genre/region/type/status filters, sorting, and cursor pagination.
//

import Foundation

/// Sort options matching the website's SortSelect.
enum BrowseSortOption: String, CaseIterable, Identifiable, Sendable {
    case updatedAtDesc = "updated_at-desc"
    case viewsDesc = "views-desc"
    case dailyViewsDesc = "daily_views-desc"
    case ratingDesc = "rating-desc"
    case releaseDateDesc = "release_date-desc"
    case latestEpisodeDesc = "latest_episode-desc"
    case bookmarkCountDesc = "bookmark_count-desc"
    case episodeCountDesc = "episode_count-desc"
    case titleAsc = "title-asc"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .updatedAtDesc: return "Cập nhật gần đây"
        case .viewsDesc: return "Phổ biến nhất"
        case .dailyViewsDesc: return "Hot hôm nay"
        case .ratingDesc: return "Đánh giá cao"
        case .releaseDateDesc: return "Mới nhất"
        case .latestEpisodeDesc: return "Tập mới nhất"
        case .bookmarkCountDesc: return "Bookmark nhiều nhất"
        case .episodeCountDesc: return "Nhiều tập nhất"
        case .titleAsc: return "A → Z"
        }
    }

    var sortBy: String {
        guard let lastDash = rawValue.lastIndex(of: "-") else { return rawValue }
        return String(rawValue[rawValue.startIndex..<lastDash])
    }

    var sortOrder: String {
        guard let lastDash = rawValue.lastIndex(of: "-") else { return "desc" }
        return String(rawValue[rawValue.index(after: lastDash)...])
    }
}

/// Content type filter.
enum BrowseTypeFilter: String, CaseIterable, Identifiable, Sendable {
    case all
    case movie
    case series

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: return "Tất cả"
        case .movie: return "Phim lẻ"
        case .series: return "Phim bộ"
        }
    }

    var icon: String {
        switch self {
        case .all: return "film.stack"
        case .movie: return "film"
        case .series: return "tv"
        }
    }
}

/// Content status filter.
enum BrowseStatusFilter: String, CaseIterable, Identifiable, Sendable {
    case all
    case ongoing
    case completed
    case trailer

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: return "Tất cả"
        case .ongoing: return "Đang chiếu"
        case .completed: return "Hoàn thành"
        case .trailer: return "Sắp chiếu"
        }
    }

    var icon: String {
        switch self {
        case .all: return "list.bullet"
        case .ongoing: return "play.circle"
        case .completed: return "checkmark.circle"
        case .trailer: return "film"
        }
    }
}

@Observable
@MainActor
final class BrowseViewModel {
    // MARK: - Constants

    private static let pageSize = 24

    // MARK: - State

    var contents: [Content] = []
    var genres: [Genre] = []
    var regions: [Region] = []
    var totalCount: Int = 0
    var hasMore: Bool = false
    var nextCursor: String?

    var isLoading = false
    var isLoadingMore = false
    var isLoadingTaxonomies = false
    var error: String?

    /// Toggled to trigger scroll-to-top in the view.
    var scrollToTopTrigger = UUID()

    // MARK: - Filter State

    var searchText: String = ""
    var selectedGenreSlugs: Set<String> = []
    var selectedRegionSlugs: Set<String> = []
    var selectedType: BrowseTypeFilter = .all
    var selectedStatus: BrowseStatusFilter = .all
    var sortOption: BrowseSortOption = .updatedAtDesc

    /// Locked type (for sub-pages like /browse/movies or /browse/tv).
    var lockedType: ContentType?

    // MARK: - Dependencies

    private let apiClient: APIClientProtocol
    private var searchTask: Task<Void, Never>?
    private var fetchId: UUID?

    init(apiClient: APIClientProtocol = APIClient(), lockedType: ContentType? = nil) {
        self.apiClient = apiClient
        self.lockedType = lockedType
        if let lockedType {
            self.selectedType = lockedType == .movie ? .movie : .series
        }
    }

    // MARK: - Computed

    var hasActiveFilters: Bool {
        !searchText.isEmpty ||
        !selectedGenreSlugs.isEmpty ||
        !selectedRegionSlugs.isEmpty ||
        selectedType != .all ||
        selectedStatus != .all
    }

    var activeFilterCount: Int {
        var count = 0
        if !searchText.isEmpty { count += 1 }
        count += selectedGenreSlugs.count
        count += selectedRegionSlugs.count
        if selectedType != .all { count += 1 }
        if selectedStatus != .all { count += 1 }
        return count
    }

    // MARK: - Build Query Params

    private func buildParams(cursor: String? = nil) -> String {
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "page_size", value: "\(Self.pageSize)")
        ]

        if !searchText.isEmpty {
            queryItems.append(URLQueryItem(name: "q", value: searchText))
        }

        // Type: locked type takes priority
        if let locked = lockedType {
            queryItems.append(URLQueryItem(name: "type", value: locked.rawValue))
        } else if selectedType != .all {
            queryItems.append(URLQueryItem(name: "type", value: selectedType.rawValue))
        }

        if !selectedGenreSlugs.isEmpty {
            queryItems.append(URLQueryItem(name: "genre", value: selectedGenreSlugs.sorted().joined(separator: ",")))
        }

        if !selectedRegionSlugs.isEmpty {
            queryItems.append(URLQueryItem(name: "region", value: selectedRegionSlugs.sorted().joined(separator: ",")))
        }

        if selectedStatus != .all {
            queryItems.append(URLQueryItem(name: "status", value: selectedStatus.rawValue))
        }

        queryItems.append(URLQueryItem(name: "sort_by", value: sortOption.sortBy))
        queryItems.append(URLQueryItem(name: "sort_order", value: sortOption.sortOrder))

        if let cursor {
            queryItems.append(URLQueryItem(name: "cursor", value: cursor))
        }

        var components = URLComponents()
        // Encode each value with a query-VALUE-safe set so characters like
        // '+', '&', '=' survive (URLComponents.percentEncodedQuery leaves '+' raw,
        // which the server would read as a space).
        components.percentEncodedQueryItems = queryItems.map {
            URLQueryItem(
                name: $0.name,
                value: $0.value?.addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed)
            )
        }
        return components.percentEncodedQuery ?? ""
    }

    // MARK: - Load Taxonomies

    func loadTaxonomies() async {
        guard genres.isEmpty else { return }
        isLoadingTaxonomies = true
        do {
            async let genresResult = apiClient.fetchGenres()
            async let regionsResult = apiClient.fetchRegions()
            let (fetchedGenres, fetchedRegions) = try await (genresResult, regionsResult)

            genres = fetchedGenres
                .filter { ($0.contentCount ?? 0) > 5 }
                .sorted { ($0.contentCount ?? 0) > ($1.contentCount ?? 0) }
            regions = fetchedRegions
                .filter { ($0.contentCount ?? 0) > 5 }
                .sorted { ($0.contentCount ?? 0) > ($1.contentCount ?? 0) }
        } catch {
            // Silently fail for taxonomies
        }
        isLoadingTaxonomies = false
    }

    // MARK: - Fetch Contents

    func fetchContents() async {
        let currentFetchId = UUID()
        fetchId = currentFetchId

        isLoading = true
        isLoadingMore = false   // a fresh fetch supersedes any in-flight pagination
        error = nil
        scrollToTopTrigger = UUID()
        // Guarantee isLoading resets on all exit paths (including stale guard returns)
        defer { if fetchId == currentFetchId { isLoading = false } }

        do {
            let params = buildParams()
            let result = try await apiClient.fetchContentsPaginated(params: params)

            // Guard stale responses
            guard fetchId == currentFetchId else { return }

            contents = result.data
            totalCount = result.pagination?.totalCount ?? result.data.count
            hasMore = result.pagination?.hasMore ?? false
            nextCursor = result.pagination?.nextCursor
        } catch let fetchError {
            guard fetchId == currentFetchId else { return }
            self.error = fetchError.localizedDescription
            contents = []
            totalCount = 0
            hasMore = false
            nextCursor = nil
        }
    }

    // MARK: - Load More (Cursor Pagination)

    func loadMore() async {
        guard hasMore, let cursor = nextCursor, !isLoadingMore else { return }
        // Capture the active fetch identity so a filter/search change that starts
        // a new fetchContents() mid-pagination invalidates this stale page (#1).
        let currentFetchId = fetchId
        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let params = buildParams(cursor: cursor)
            let result = try await apiClient.fetchContentsPaginated(params: params)

            // Drop stale results: a newer fetch replaced the list while we awaited.
            guard fetchId == currentFetchId else { return }

            // De-dup by id: cursor pagination over volatile sort keys can return a
            // content already on a previous page, which would break ForEach identity.
            let existingIds = Set(contents.map(\.id))
            let newItems = result.data.filter { !existingIds.contains($0.id) }
            contents.append(contentsOf: newItems)
            totalCount = result.pagination?.totalCount ?? contents.count
            hasMore = result.pagination?.hasMore ?? false
            nextCursor = result.pagination?.nextCursor
        } catch {
            // Silently fail for load more
        }
    }

    // MARK: - Filter Actions

    func applyFilters() {
        // Invalidate any in-flight loadMore immediately so a page returning during
        // the debounce window isn't appended to a list about to be replaced (#1).
        fetchId = UUID()
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await fetchContents()
        }
    }

    func clearFilters() {
        selectedGenreSlugs = []
        selectedRegionSlugs = []
        selectedType = lockedType == nil ? .all : (lockedType == .movie ? .movie : .series)
        selectedStatus = .all
        sortOption = .updatedAtDesc
        // Set searchText last and route through the single debounced path. This
        // coalesces with the .searchable onChange (which also fires on this change)
        // into ONE fetch instead of an immediate fetch racing a debounced one.
        searchText = ""
        applyFilters()
    }

    func toggleGenre(_ slug: String) {
        if selectedGenreSlugs.contains(slug) {
            selectedGenreSlugs.remove(slug)
        } else {
            selectedGenreSlugs.insert(slug)
        }
        applyFilters()
    }

    func toggleRegion(_ slug: String) {
        if selectedRegionSlugs.contains(slug) {
            selectedRegionSlugs.remove(slug)
        } else {
            selectedRegionSlugs.insert(slug)
        }
        applyFilters()
    }

    func setType(_ type: BrowseTypeFilter) {
        guard lockedType == nil else { return }
        selectedType = type
        applyFilters()
    }

    func setStatus(_ status: BrowseStatusFilter) {
        selectedStatus = status
        applyFilters()
    }

    func setSort(_ option: BrowseSortOption) {
        sortOption = option
        applyFilters()
    }

    func searchChanged() {
        applyFilters()
    }

    /// Cancel any pending search/filter tasks — call from .onDisappear.
    func cancelPending() {
        searchTask?.cancel()
        searchTask = nil
    }
}
