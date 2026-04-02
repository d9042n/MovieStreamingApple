//
//  PersonDetailViewModel.swift
//  MovieStreamingApple
//
//  ViewModel for PersonDetail — mirrors usePersonDetail hook from the website.
//

import Foundation
import SwiftUI

// MARK: - Department Label Mapping

private let deptLabelMap: [String: String] = [
    "acting": "Diễn viên",
    "directing": "Đạo diễn",
    "writing": "Biên kịch",
    "production": "Nhà sản xuất",
    "crew": "Hậu trường",
    "creator": "Sáng tạo",
]

// MARK: - View Model

@Observable
@MainActor
final class PersonDetailViewModel {
    // MARK: - State

    var person: PersonDetail? {
        didSet { cachedBackdropURLs = nil } // Invalidate cache on person change (#37)
    }
    var isLoading = false
    var error: String?

    // UI state
    var bioExpanded = false
    var filmShowAll: [String: Bool] = [:]
    var selectedTab: PersonTab = .biography

    // MARK: - Dependencies

    private let apiClient: APIClientProtocol

    init(apiClient: APIClientProtocol = APIClient()) {
        self.apiClient = apiClient
    }

    // MARK: - Computed

    var socialLinks: ParsedSocialLinks {
        person?.socialLinks?.parsed ?? ParsedSocialLinks()
    }

    var departmentLabel: String {
        guard let filmography = person?.filmography else { return "" }
        let depts = Array(filmography.keys)
        guard let first = depts.first else { return "" }
        return Self.getDepartmentLabel(first)
    }

    /// Cached age calculation using shared DateFormatting (#34).
    var age: Int? {
        guard let birthDate = person?.birthDate else { return nil }
        return DateFormatting.calculateAge(from: birthDate)
    }

    /// Formatted birth date using shared DateFormatting (#34).
    var formattedBirthDate: String? {
        guard let birthDate = person?.birthDate else { return nil }
        return DateFormatting.formatLong(birthDate) ?? birthDate
    }

    var totalContents: Int {
        person?.totalContents ?? 0
    }

    /// Best backdrop URL from filmography (highest rated).
    var bestBackdropURL: URL? {
        allBackdropURLs.first
    }

    /// Cached backdrop URLs — avoids recomputation per render (#37).
    private var cachedBackdropURLs: [URL]?

    /// All unique backdrop URLs from filmography (sorted by rating, max 6).
    var allBackdropURLs: [URL] {
        if let cached = cachedBackdropURLs { return cached }
        let urls = computeBackdropURLs()
        cachedBackdropURLs = urls
        return urls
    }

    private func computeBackdropURLs() -> [URL] {
        guard let filmography = person?.filmography else { return [] }
        let allItems = filmography.values.flatMap { $0 }
        let sorted = allItems
            .filter { $0.backdropUrl != nil }
            .sorted { ($0.averageRating ?? 0) > ($1.averageRating ?? 0) }
        var seen = Set<String>()
        var urls: [URL] = []
        for item in sorted {
            guard let urlString = item.backdropUrl, !seen.contains(urlString),
                  let url = URL(string: urlString) else { continue }
            seen.insert(urlString)
            urls.append(url)
            if urls.count >= 6 { break }
        }
        return urls
    }

    var displayedBio: String? {
        guard let bio = person?.bio, !bio.isEmpty else { return nil }
        if bio.count > 500 && !bioExpanded {
            return String(bio.prefix(500)) + "..."
        }
        return bio
    }

    var bioIsLong: Bool {
        (person?.bio?.count ?? 0) > 500
    }

    // MARK: - Actions

    func loadPerson(slug: String) async {
        isLoading = true
        error = nil

        do {
            person = try await apiClient.fetchPersonDetail(slug: slug)
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func retry(slug: String) async {
        error = nil
        person = nil
        await loadPerson(slug: slug)
    }

    // MARK: - Filmography Helpers

    /// Get sorted filmography items for a department (newest first).
    func sortedFilmography(for dept: String) -> [FilmographyItem] {
        guard let items = person?.filmography?[dept] else { return [] }
        return items.sorted { item1, item2 in
            let date1 = DateFormatting.extractYear(item1.releaseDate)
            let date2 = DateFormatting.extractYear(item2.releaseDate)
            return date2 < date1
        }
    }

    /// Get display items (paginated or all).
    func displayItems(for dept: String) -> [FilmographyItem] {
        let sorted = sortedFilmography(for: dept)
        let showAll = filmShowAll[dept] ?? false
        return showAll ? sorted : Array(sorted.prefix(20))
    }

    func hasMoreItems(for dept: String) -> Bool {
        sortedFilmography(for: dept).count > 20
    }

    func toggleShowAll(for dept: String) {
        filmShowAll[dept] = !(filmShowAll[dept] ?? false)
    }

    // MARK: - Static Helpers

    static func getDepartmentLabel(_ key: String) -> String {
        deptLabelMap[key] ?? key.prefix(1).uppercased() + key.dropFirst()
    }

    static func getStatusInfo(_ status: String?) -> (label: String, color: String)? {
        switch status {
        case "ongoing": return ("Đang Chiếu", "highlight")
        case "completed": return ("Hoàn Tất", "brand")
        case "trailer": return ("Sắp Chiếu", "muted")
        default: return nil
        }
    }
}

// MARK: - Person Tab

enum PersonTab: String, CaseIterable, Identifiable, Sendable {
    case biography
    case filmography

    var id: String { rawValue }

    func label(totalContents: Int) -> String {
        switch self {
        case .biography: return "Tiểu Sử"
        case .filmography:
            return totalContents > 0 ? "Tác Phẩm (\(totalContents))" : "Tác Phẩm"
        }
    }
}
