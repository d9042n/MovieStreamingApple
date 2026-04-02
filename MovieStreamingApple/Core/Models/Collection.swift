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
}
