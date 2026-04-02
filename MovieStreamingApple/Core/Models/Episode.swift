//
//  Episode.swift
//  MovieStreamingApple
//
//  Episode model matching `GET /api/v1/tv/{slug}/episodes` response.
//  Updated to include streaming servers and subtitles for Watch page.
//

import Foundation

/// Represents a single episode within a season.
nonisolated struct Episode: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let tmdbId: Int?
    let slug: String?
    let seasonNumber: Int?
    let episodeNumber: Int?
    let episodeType: String?
    let sortOrder: Int?
    let title: String?
    let description: String?
    let thumbnailUrl: String?
    let durationSeconds: Int?
    let airDate: String?
    let averageRating: Double?
    let isPublished: Bool?

    // Streaming data (populated from watch/detail endpoints)
    let servers: [StreamingLink]?
    let subtitles: [SubtitleTrack]?

    /// Formatted duration from seconds.
    var formattedDuration: String? {
        guard let seconds = durationSeconds, seconds > 0 else { return nil }
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }

    /// Whether this is a standard episode (not a special).
    var isStandard: Bool {
        episodeType == nil || episodeType == "standard"
    }

    /// Whether this episode was released within the last 7 days.
    var isRecent: Bool {
        guard let airDateStr = airDate else { return false }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        guard let date = formatter.date(from: airDateStr) else { return false }
        return Date().timeIntervalSince(date) < 7 * 24 * 60 * 60
    }
}
