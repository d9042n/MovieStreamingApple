//
//  WatchHistoryManager.swift
//  MovieStreamingApple
//
//  Manages watch history for the "Continue Watching" hub.
//  Persists MINIMAL entries to UserDefaults (slug + progress + date).
//  Rich display data (title, poster, duration) is fetched from API on demand.
//
//  Future: Will sync with user account via API.
//

import Foundation
import os
import SwiftUI


// MARK: - Watch History Entry (Minimal — persisted to UserDefaults)

struct WatchHistoryEntry: Codable, Identifiable, Hashable, Sendable {
    /// 1 entry per content — ID is always the slug.
    var id: String { slug }

    let slug: String
    let contentType: ContentType
    var progress: Double          // 0.0 – 1.0 normalized (current episode or movie)
    var lastWatchedDate: Date

    // MARK: - Series Episode Tracking
    var seasonNumber: Int?        // series: current season being watched
    var episodeNumber: Int?       // series: current episode being watched
    var currentEpisodeId: String? // series: episode ID for resume key

    // MARK: - Resume Position
    /// Exact playback position in seconds for resume (unified with VideoPlayerVM).
    var resumePositionSeconds: TimeInterval

    /// Whether user has essentially finished (progress >= 95%)
    var isFinished: Bool { progress >= 0.95 }

    // MARK: - Backward Compatibility Codable
    
    enum CodingKeys: String, CodingKey {
        case slug, contentType, progress, lastWatchedDate
        case seasonNumber, episodeNumber, currentEpisodeId
        case resumePositionSeconds
    }

    // Default memberwise init since custom decoders drop it
    init(slug: String, contentType: ContentType, progress: Double, lastWatchedDate: Date, seasonNumber: Int? = nil, episodeNumber: Int? = nil, currentEpisodeId: String? = nil, resumePositionSeconds: TimeInterval) {
        self.slug = slug
        self.contentType = contentType
        self.progress = progress
        self.lastWatchedDate = lastWatchedDate
        self.seasonNumber = seasonNumber
        self.episodeNumber = episodeNumber
        self.currentEpisodeId = currentEpisodeId
        self.resumePositionSeconds = resumePositionSeconds
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        slug = try container.decode(String.self, forKey: .slug)
        contentType = try container.decode(ContentType.self, forKey: .contentType)
        progress = try container.decode(Double.self, forKey: .progress)
        lastWatchedDate = try container.decode(Date.self, forKey: .lastWatchedDate)
        seasonNumber = try container.decodeIfPresent(Int.self, forKey: .seasonNumber)
        episodeNumber = try container.decodeIfPresent(Int.self, forKey: .episodeNumber)
        currentEpisodeId = try container.decodeIfPresent(String.self, forKey: .currentEpisodeId)
        // Default to 0 if missing from old data
        resumePositionSeconds = try container.decodeIfPresent(TimeInterval.self, forKey: .resumePositionSeconds) ?? 0.0
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(slug, forKey: .slug)
        try container.encode(contentType, forKey: .contentType)
        try container.encode(progress, forKey: .progress)
        try container.encode(lastWatchedDate, forKey: .lastWatchedDate)
        try container.encodeIfPresent(seasonNumber, forKey: .seasonNumber)
        try container.encodeIfPresent(episodeNumber, forKey: .episodeNumber)
        try container.encodeIfPresent(currentEpisodeId, forKey: .currentEpisodeId)
        try container.encode(resumePositionSeconds, forKey: .resumePositionSeconds)
    }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
}

// MARK: - Watch Display Data (Rich — fetched from API, NOT persisted)

struct WatchDisplayData: Identifiable, Hashable {
    let entry: WatchHistoryEntry
    let title: String
    let posterUrl: String?
    let backdropUrl: String?
    let durationMinutes: Int?
    let episodeTitle: String?

    var id: String { entry.id }

    /// Image URL: backdrop for iPad (16:9), poster for iPhone (2:3).
    /// API may return empty string "" instead of null — treat as nil.
    func heroImageUrl(for hSizeClass: UserInterfaceSizeClass?) -> URL? {
        let poster = posterUrl.flatMap { $0.isEmpty ? nil : $0 }
        let backdrop = backdropUrl.flatMap { $0.isEmpty ? nil : $0 }
        
        let primary = hSizeClass == .regular ? backdrop : poster
        let fallback = hSizeClass == .regular ? poster : backdrop
        
        return (primary ?? fallback).flatMap { URL(string: $0) }
    }

    var cardImageUrl: URL? {
        let poster = posterUrl.flatMap { $0.isEmpty ? nil : $0 }
        let backdrop = backdropUrl.flatMap { $0.isEmpty ? nil : $0 }
        return (poster ?? backdrop).flatMap { URL(string: $0) }
    }

    /// Remaining time formatted for display
    var remainingTimeFormatted: String? {
        guard let mins = durationMinutes, mins > 0, entry.progress < 1.0 else { return nil }
        let totalSeconds = mins * 60
        let remaining = Int(Double(totalSeconds) * (1.0 - entry.progress))
        if remaining >= 3600 {
            return "\(remaining / 3600)h \((remaining % 3600) / 60)m còn"
        }
        if remaining >= 60 {
            return "\(remaining / 60) phút còn"
        }
        return nil
    }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
}

// MARK: - Loading State

enum WatchHistoryLoadingState: Sendable, Equatable {
    case idle
    case loading
    case loaded
    case error(String)
}

// MARK: - Watch History Manager

@Observable
@MainActor
final class WatchHistoryManager {
    private let logger = Logger(subsystem: "com.d9042n.moviestreaming", category: "WatchHistory")
    private static let storageKey = "watch-history"
    static let maxEntries = 30

    /// Minimal entries persisted to UserDefaults.
    private(set) var entries: [WatchHistoryEntry] = []

    /// API-fetched content cache (keyed by slug → Content).
    /// NOT persisted — refetched each session.
    private(set) var contentCache: [String: Content] = [:]

    /// Current loading state for the hub view.
    private(set) var loadingState: WatchHistoryLoadingState = .idle

    private let apiClient: APIClientProtocol

    // MARK: - Computed Display Data

    /// All entries — sorted by most recent. Used by the hero slider.
    var allDisplayData: [WatchDisplayData] {
        entries
            .sorted { $0.lastWatchedDate > $1.lastWatchedDate }
            .compactMap { displayData(for: $0) }
    }

    /// Continue watching: has active progress, not finished — sorted by most recent.
    var continueWatching: [WatchDisplayData] {
        entries
            .filter { $0.progress > 0.01 && !$0.isFinished }
            .sorted { $0.lastWatchedDate > $1.lastWatchedDate }
            .compactMap { displayData(for: $0) }
    }

    /// Recently viewed: finished or barely started — sorted by most recent.
    var recentlyViewed: [WatchDisplayData] {
        entries
            .filter { $0.isFinished || $0.progress <= 0.01 }
            .sorted { $0.lastWatchedDate > $1.lastWatchedDate }
            .compactMap { displayData(for: $0) }
    }

    /// The most recently watched entry that's still in progress (for hero).
    var lastWatched: WatchDisplayData? {
        let entry = entries
            .filter { !$0.isFinished && $0.progress > 0.01 }
            .max { $0.lastWatchedDate < $1.lastWatchedDate }
            ?? entries.first
        guard let entry else { return nil }
        return displayData(for: entry)
    }

    /// Whether there's any watch history at all.
    var isEmpty: Bool { entries.isEmpty }

    /// Whether content data has been fetched from API.
    var isContentLoaded: Bool { loadingState == .loaded }

    // MARK: - Init

    init(apiClient: APIClientProtocol = APIClient()) {
        self.apiClient = apiClient
        loadFromDisk()
    }

    // MARK: - Fetch Content Details (batch)

    /// Fetch rich content data from API for all unique slugs in history.
    /// Called by WatchingHubView on appear.
    func fetchContentDetails() async {
        guard !entries.isEmpty else {
            loadingState = .loaded
            return
        }

        // Skip if already loaded for this session
        if case .loaded = loadingState, !contentCache.isEmpty { return }

        loadingState = .loading

        // Deduplicate by slug (multiple episodes → same slug for series)
        let uniqueEntries = Dictionary(grouping: entries, by: \.slug)
            .compactMapValues(\.first)

        let taskLogger = self.logger
        await withTaskGroup(of: (String, Content?).self) { group in
            for (slug, entry) in uniqueEntries {
                // Skip if already cached
                guard contentCache[slug] == nil else { continue }
                group.addTask { [apiClient, taskLogger] in
                    do {
                        let content = try await apiClient.fetchContentDetail(
                            slug: slug,
                            type: entry.contentType
                        )
                        return (slug, content)
                    } catch {
                        taskLogger.warning("Failed to fetch detail for \(slug): \(error.localizedDescription)")
                        return (slug, nil)
                    }
                }
            }

            for await (slug, content) in group {
                if let content {
                    contentCache[slug] = content
                }
            }
        }

        loadingState = .loaded
        logger.info("Fetched \(self.contentCache.count) content details for watch history")
    }

    // MARK: - Display Data Helper

    /// Build rich display data by merging local entry + API content.
    func displayData(for entry: WatchHistoryEntry) -> WatchDisplayData? {
        guard let content = contentCache[entry.slug] else { return nil }
        return WatchDisplayData(
            entry: entry,
            title: content.title,
            posterUrl: content.posterUrl,
            backdropUrl: content.backdropUrl,
            durationMinutes: content.durationMinutes,
            episodeTitle: nil // TODO: fetch from episodes API if needed
        )
    }

    // MARK: - Add / Update

    func addOrUpdate(
        slug: String,
        contentType: ContentType,
        progress: Double,
        resumePosition: TimeInterval = 0,
        seasonNumber: Int? = nil,
        episodeNumber: Int? = nil,
        episodeId: String? = nil
    ) {
        let clampedProgress = max(0, min(1, progress))

        // KEY: Always match by slug — 1 entry per content
        if let index = entries.firstIndex(where: { $0.slug == slug }) {
            var entry = entries.remove(at: index)
            entry.progress = clampedProgress
            entry.resumePositionSeconds = resumePosition
            entry.lastWatchedDate = Date()
            entry.seasonNumber = seasonNumber
            entry.episodeNumber = episodeNumber
            entry.currentEpisodeId = episodeId
            entries.insert(entry, at: 0)
        } else {
            let entry = WatchHistoryEntry(
                slug: slug,
                contentType: contentType,
                progress: clampedProgress,
                lastWatchedDate: Date(),
                seasonNumber: seasonNumber,
                episodeNumber: episodeNumber,
                currentEpisodeId: episodeId,
                resumePositionSeconds: resumePosition
            )
            entries.insert(entry, at: 0)
        }

        // Prune to max
        if entries.count > Self.maxEntries {
            entries = Array(entries.prefix(Self.maxEntries))
        }

        saveToDisk()
    }

    // MARK: - Remove

    func remove(entryId: String) {
        entries.removeAll { $0.id == entryId }
        saveToDisk()
    }

    func clearAll() {
        entries.removeAll()
        contentCache.removeAll()
        saveToDisk()
    }

    // MARK: - Persistence

    private func saveToDisk() {
        do {
            let data = try JSONEncoder().encode(entries)
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        } catch {
            logger.error("Failed to save watch history: \(error.localizedDescription)")
        }
    }

    private func loadFromDisk() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey) else { return }
        do {
            let decoded = try JSONDecoder().decode([WatchHistoryEntry].self, from: data)
            // Migrate: group old per-episode entries → 1 entry per slug
            entries = migrateToPerSlug(decoded)
            if entries.count != decoded.count {
                logger.info("Migrated \(decoded.count) entries → \(self.entries.count) (per-slug grouping)")
                saveToDisk()
            }
            logger.info("Loaded \(self.entries.count) watch history entries")
        } catch {
            logger.error("Failed to load watch history: \(error.localizedDescription)")
            entries = []
        }
    }

    // MARK: - Migration (per-episode → per-slug)

    /// Groups old per-episode entries by slug, keeping only the most recent.
    private func migrateToPerSlug(_ rawEntries: [WatchHistoryEntry]) -> [WatchHistoryEntry] {
        var seen = Set<String>()
        var result: [WatchHistoryEntry] = []

        // Sort by most recent first, so the first seen slug is the latest
        let sorted = rawEntries.sorted { $0.lastWatchedDate > $1.lastWatchedDate }
        for entry in sorted {
            if !seen.contains(entry.slug) {
                seen.insert(entry.slug)
                result.append(entry)
            }
        }
        return result
    }
}
