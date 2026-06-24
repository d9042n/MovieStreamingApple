//
//  PeopleViewModel.swift
//  MovieStreamingApple
//
//  ViewModel for the People directory — mirrors usePeople hook from the website.
//  Cursor-based pagination, search, sort, and gender filtering.
//

import Foundation

/// Sort options matching the web.
enum PeopleSortOption: String, CaseIterable, Identifiable, Sendable {
    case nameAsc = "name-asc"
    case nameDesc = "name-desc"
    case popularityDesc = "popularity-desc"
    case createdAtDesc = "created_at-desc"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .nameAsc: return "Tên A → Z"
        case .nameDesc: return "Tên Z → A"
        case .popularityDesc: return "Nhiều phim nhất"
        case .createdAtDesc: return "Mới cập nhật"
        }
    }

    var sortBy: String {
        switch self {
        case .nameAsc, .nameDesc: return "name"
        case .popularityDesc: return "popularity"
        case .createdAtDesc: return "created_at"
        }
    }

    var sortOrder: String {
        switch self {
        case .nameAsc: return "asc"
        case .nameDesc, .popularityDesc, .createdAtDesc: return "desc"
        }
    }
}

/// Gender filter options.
enum GenderFilter: String, CaseIterable, Identifiable, Sendable {
    case all = ""
    case male = "male"
    case female = "female"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: return "Tất cả"
        case .male: return "Nam"
        case .female: return "Nữ"
        }
    }
}

@Observable
@MainActor
final class PeopleViewModel {
    // MARK: - State

    var people: [PersonListItem] = []
    var isLoading = false
    var isLoadingMore = false
    var error: String?

    // Pagination
    var hasMore = false
    var nextCursor: String?
    var totalCount: Int?

    // Filters
    var searchText = ""
    var selectedSort: PeopleSortOption = .nameAsc
    var selectedGender: GenderFilter = .all

    // Search debounce
    private var searchTask: Task<Void, Never>?
    private var debouncedSearch = ""

    // MARK: - Dependencies

    private let apiClient: APIClientProtocol

    init(apiClient: APIClientProtocol = APIClient()) {
        self.apiClient = apiClient
    }

    // MARK: - Computed

    var hasActiveFilters: Bool {
        !debouncedSearch.isEmpty || selectedGender != .all || selectedSort != .nameAsc
    }

    /// Toggled to trigger scroll-to-top in the view.
    var scrollToTopTrigger = UUID()

    // MARK: - Actions

    /// Initial load or filter change.
    func loadPeople() async {
        isLoading = true
        error = nil
        scrollToTopTrigger = UUID()

        do {
            let result = try await apiClient.fetchPeople(
                pageSize: 24,
                sortBy: selectedSort.sortBy,
                sortOrder: selectedSort.sortOrder,
                search: debouncedSearch,
                gender: selectedGender.rawValue,
                cursor: nil
            )
            people = result.data
            hasMore = result.pagination?.hasMore ?? false
            nextCursor = result.pagination?.nextCursor
            totalCount = result.pagination?.totalCount
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    /// Load more (cursor pagination).
    func loadMore() async {
        guard hasMore, !isLoadingMore, let cursor = nextCursor else { return }
        isLoadingMore = true

        do {
            let result = try await apiClient.fetchPeople(
                pageSize: 24,
                sortBy: selectedSort.sortBy,
                sortOrder: selectedSort.sortOrder,
                search: debouncedSearch,
                gender: selectedGender.rawValue,
                cursor: cursor
            )
            // Deduplicate to prevent duplicate entries from cursor pagination (#8)
            let existingIds = Set(people.map(\.id))
            let newPeople = result.data.filter { !existingIds.contains($0.id) }
            people.append(contentsOf: newPeople)
            hasMore = result.pagination?.hasMore ?? false
            nextCursor = result.pagination?.nextCursor
            totalCount = result.pagination?.totalCount
        } catch {
            // Silently fail on load more
        }

        isLoadingMore = false
    }

    /// Debounced search handler (#9 — clean pattern).
    func onSearchChanged(_ newValue: String) {
        // Ignore programmatic resets (e.g. clearFilters set searchText = "") where
        // the value already matches debouncedSearch — avoids a duplicate load.
        guard newValue != debouncedSearch else { return }
        searchTask?.cancel()
        searchTask = Task {
            do {
                try await Task.sleep(for: .milliseconds(350))
            } catch {
                return // Task cancelled — user typed again
            }
            debouncedSearch = newValue
            await loadPeople()
        }
    }

    /// Filter change: sort or gender.
    func onFilterChanged() async {
        await loadPeople()
    }

    /// Clear all filters.
    func clearFilters() async {
        // Cancel any pending debounced search and set debouncedSearch FIRST so the
        // .searchable onChange (firing for searchText = "") becomes a no-op and we
        // don't race a second loadPeople().
        searchTask?.cancel()
        debouncedSearch = ""
        searchText = ""
        selectedGender = .all
        selectedSort = .nameAsc
        await loadPeople()
    }

    /// Retry after error.
    func retry() async {
        error = nil
        people = []
        await loadPeople()
    }
}
