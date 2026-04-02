//
//  Season.swift
//  MovieStreamingApple
//
//  Season model matching `GET /api/v1/tv/{slug}/seasons` response.
//

import Foundation

/// Represents a season of a TV series.
nonisolated struct Season: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let tmdbId: Int?
    let seasonNumber: Int?
    let title: String
    let description: String?
    let posterUrl: String?
    let airDate: String?
    let averageRating: Double?
    let episodeCount: Int?
}
