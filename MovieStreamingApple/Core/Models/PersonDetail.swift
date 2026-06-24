//
//  PersonDetail.swift
//  MovieStreamingApple
//
//  PersonDetail model matching GET /api/v1/people/:slug response.
//

import Foundation

/// Filmography item — a content the person worked on.
nonisolated struct FilmographyItem: Codable, Identifiable, Hashable, Sendable {
    var id: String { contentId }
    let contentId: String
    let title: String
    let slug: String
    let posterUrl: String?
    let backdropUrl: String?
    let type: String?
    let status: String?
    let releaseDate: String?
    let characterName: String?
    let averageRating: Double?
    let episodeCount: Int?
}

/// Detailed person info from /api/v1/people/:slug.
nonisolated struct PersonDetail: Codable, Identifiable, Sendable {
    let id: String
    let tmdbId: Int?
    let name: String
    let slug: String
    let gender: String?
    let isFeatured: Bool?
    let photoUrl: String?
    let bio: String?
    let birthDate: String?
    let birthPlace: String?
    let nationality: String?
    let socialLinks: SocialLinksRaw?
    let filmography: [String: [FilmographyItem]]?
    let alsoKnownAs: [String]?
    let mediaCount: Int?
    let totalContents: Int?
    let createdAt: String?
    let updatedAt: String?
}

/// Social links can be a JSON object or a base64 string.
/// We decode it into a known structure.
enum SocialLinksRaw: Codable, Sendable {
    case object(ParsedSocialLinks)
    case string(String)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let obj = try? container.decode(ParsedSocialLinks.self) {
            self = .object(obj)
        } else if let str = try? container.decode(String.self) {
            self = .string(str)
        } else {
            self = .object(ParsedSocialLinks())
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .object(let links): try container.encode(links)
        case .string(let str): try container.encode(str)
        }
    }

    /// Snake-case decoder for the string fallback below. Must match the shared
    /// APIClient decoder's strategy so `imdb_id` maps to `imdbId` consistently.
    private static let snakeDecoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    /// Parse into a usable structure.
    var parsed: ParsedSocialLinks {
        switch self {
        case .object(let links):
            return links
        case .string(let str):
            // Try base64 decode first, then JSON (both with snake_case mapping).
            if let data = Data(base64Encoded: str),
               let links = try? Self.snakeDecoder.decode(ParsedSocialLinks.self, from: data) {
                return links
            }
            if let data = str.data(using: .utf8),
               let links = try? Self.snakeDecoder.decode(ParsedSocialLinks.self, from: data) {
                return links
            }
            return ParsedSocialLinks()
        }
    }
}

nonisolated struct ParsedSocialLinks: Codable, Sendable {
    var imdbId: String?
    var twitterId: String?
    var facebookId: String?
    var instagramId: String?

    // NOTE: No explicit snake_case CodingKeys here. The shared APIClient decoder
    // uses `.convertFromSnakeCase`, which already maps imdb_id → imdbId; explicit
    // "imdb_id" keys would be double-converted and NEVER match (all fields nil).

    var hasAny: Bool {
        imdbId != nil || twitterId != nil || facebookId != nil || instagramId != nil
    }

    var hasSocialMedia: Bool {
        twitterId != nil || facebookId != nil || instagramId != nil
    }
}
