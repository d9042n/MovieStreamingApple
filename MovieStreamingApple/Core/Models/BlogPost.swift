//
//  BlogPost.swift
//  MovieStreamingApple
//

import Foundation

/// Blog post from `/api/v1/blog/posts`.
nonisolated struct BlogPost: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let excerpt: String?
    let content: String?
    let imageUrl: String?
    let publishedAt: String?
    let viewCount: Int?
    let authorName: String?
    let categoryName: String?

    /// Formatted publish date.
    var formattedDate: String? {
        guard let dateStr = publishedAt else { return nil }
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var parsed = isoFormatter.date(from: dateStr)
        if parsed == nil {
            // Retry without fractional seconds — ISO8601DateFormatter is strict and
            // returns nil for "2026-01-02T03:04:05Z" when .withFractionalSeconds is set.
            isoFormatter.formatOptions = [.withInternetDateTime]
            parsed = isoFormatter.date(from: dateStr)
        }
        guard let date = parsed else { return nil }
        let displayFormatter = DateFormatter()
        displayFormatter.locale = Locale(identifier: "vi_VN")
        displayFormatter.dateStyle = .medium
        return displayFormatter.string(from: date)
    }
}
