//
//  Collection.swift
//  MovieStreamingApple
//

import Foundation

/// A curated editorial collection of content (Netflix/Disney+ style rail).
/// Matches `GET /api/v1/collections` response.
nonisolated struct ContentCollection: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let slug: String
    let type: String?
    let sortOrder: Int
    let contents: [Content]

    enum CodingKeys: String, CodingKey {
        case id, title, slug, type, sortOrder, contents
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        // Tolerate missing/null optional-ish fields so an otherwise-valid collection
        // (e.g. an empty one with no `contents` key) still decodes instead of being dropped.
        title = (try? c.decodeIfPresent(String.self, forKey: .title)) ?? ""
        slug = (try? c.decodeIfPresent(String.self, forKey: .slug)) ?? ""
        type = try? c.decodeIfPresent(String.self, forKey: .type)
        sortOrder = (try? c.decodeIfPresent(Int.self, forKey: .sortOrder)) ?? 0
        // Lossy contents — defaults to [] and skips any malformed item.
        contents = (try? c.decodeLossyArray(Content.self, forKey: .contents)) ?? []
    }
}
