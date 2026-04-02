//
//  Genre.swift
//  MovieStreamingApple
//

import Foundation

/// Genre model returned by `/api/v1/genres`.
nonisolated struct Genre: Codable, Identifiable, Hashable, Sendable {
    let id: String?
    let name: String
    let slug: String
    let description: String?
    let contentCount: Int?
}
