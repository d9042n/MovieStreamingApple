//
//  Content.swift
//  MovieStreamingApple
//
//  Domain model matching the backend API v2 Unified Content Model.
//

import Foundation

/// Represents a movie or TV series from the backend.
nonisolated struct Content: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let tmdbId: Int?
    let imdbId: String?
    let title: String
    let slug: String?
    let originalTitle: String?
    let description: String?
    let posterUrl: String?
    let backdropUrl: String?
    let trailerUrl: String?
    let releaseDate: String?
    let durationMinutes: Int?
    let seasonCount: Int?
    let episodeCount: Int?
    let latestEpisodeAt: String?
    let contentRating: String?
    let averageRating: Double?
    let ratingCount: Int?
    let totalViews: Int?
    let status: String?
    let network: String?
    let isFeatured: Bool?
    let isPublished: Bool?
    let type: ContentType?
    let genres: [GenreRef]?
    let streamingMeta: StreamingMeta?
    // Detail-specific fields (populated only from detail endpoint)
    let stats: ContentStats?
    let regions: [Region]?
    let studios: [Studio]?
    let directors: [Person]?
    let writers: [Person]?
    let topCast: [CastMember]?
    let createdAt: String?
    let updatedAt: String?

    /// The slug to use for navigation — falls back to `id` if slug is nil or empty.
    var effectiveSlug: String {
        if let slug, !slug.isEmpty { return slug }
        return id
    }

    /// Computed helper: the URL path to navigate to detail.
    var detailPath: String {
        let prefix = type == .series ? "tv" : "movie"
        return "/\(prefix)/\(effectiveSlug)"
    }

    /// Computed helper: release year.
    var releaseYear: Int? {
        guard let dateStr = releaseDate else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        if let date = formatter.date(from: dateStr) {
            return Calendar.current.component(.year, from: date)
        }
        // Fallback: try parsing just the year portion
        if dateStr.count >= 4, let year = Int(String(dateStr.prefix(4))) {
            return year
        }
        return nil
    }

    /// Computed helper: formatted duration.
    var formattedDuration: String? {
        guard let minutes = durationMinutes, minutes > 0 else { return nil }
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 {
            return "\(hours)h \(mins)m"
        }
        return "\(mins)m"
    }

    /// Computed helper: formatted views.
    var formattedViews: String? {
        guard let views = totalViews, views > 0 else { return nil }
        if views >= 1_000_000 {
            return String(format: "%.1fM", Double(views) / 1_000_000)
        }
        if views >= 1_000 {
            return String(format: "%.1fK", Double(views) / 1_000)
        }
        return "\(views)"
    }

    // MARK: - Hashable

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Content, rhs: Content) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Content Type

nonisolated enum ContentType: String, Codable, Sendable {
    case movie
    case series
}

// MARK: - Genre Reference (can be string or object in API)

nonisolated enum GenreRef: Codable, Hashable, Sendable {
    case string(String)
    case object(Genre)

    var name: String {
        switch self {
        case .string(let name): return name
        case .object(let genre): return genre.name
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else if let genreValue = try? container.decode(Genre.self) {
            self = .object(genreValue)
        } else {
            throw DecodingError.typeMismatch(
                GenreRef.self,
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Expected String or Genre object")
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let name):
            try container.encode(name)
        case .object(let genre):
            try container.encode(genre)
        }
    }
}

// MARK: - Streaming Meta

nonisolated struct StreamingMeta: Codable, Hashable, Sendable {
    let quality: String?
    let language: String?
    let episodeCurrent: String?
    let episodeTotal: String?
}
