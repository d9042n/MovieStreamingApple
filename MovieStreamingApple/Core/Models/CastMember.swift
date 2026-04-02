//
//  CastMember.swift
//  MovieStreamingApple
//
//  Cast and crew member models for content credits.
//

import Foundation

/// A cast member from the credits API.
nonisolated struct CastMember: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let slug: String?
    let photoUrl: String?
    let characterName: String?
    let department: String?

    /// First character of name for avatar placeholder.
    var initial: String {
        String(name.prefix(1)).uppercased()
    }
}

/// Credits response grouping cast and crew.
nonisolated struct CreditsResponse: Codable, Sendable {
    let cast: [CastMember]?
    let crew: [String: [CastMember]]?
}
