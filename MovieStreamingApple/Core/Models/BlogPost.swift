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
        guard let date = isoFormatter.date(from: dateStr) else { return nil }
        let displayFormatter = DateFormatter()
        displayFormatter.locale = Locale(identifier: "vi_VN")
        displayFormatter.dateStyle = .medium
        return displayFormatter.string(from: date)
    }
}
