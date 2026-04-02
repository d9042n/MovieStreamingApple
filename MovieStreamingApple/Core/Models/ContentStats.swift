//
//  ContentStats.swift
//  MovieStreamingApple
//
//  Extended statistics for content detail responses.
//

import Foundation

/// Detailed stats returned in content detail response.
nonisolated struct ContentStats: Codable, Hashable, Sendable {
    let totalViews: Int?
    let dailyViews: Int?
    let ratingCount: Int?
    let averageRating: Double?
    let bookmarkCount: Int?
    let reviewCount: Int?
}

/// Studio information.
nonisolated struct Studio: Codable, Hashable, Sendable {
    let id: String?
    let name: String
    let slug: String
}

/// Region/country information.
nonisolated struct Region: Codable, Identifiable, Hashable, Sendable {
    let id: String?
    let name: String
    let slug: String
    let description: String?
    let contentCount: Int?
}

/// Person (director/writer) reference.
nonisolated struct Person: Codable, Hashable, Sendable {
    let id: String?
    let name: String?
    let slug: String?
    let photoUrl: String?
    let department: String?
    let characterName: String?
}
