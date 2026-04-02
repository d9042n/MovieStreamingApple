// PersonListItem model matching GET /api/v1/people response.

import Foundation

/// Known-for item: a content the person appeared in.
nonisolated struct KnownForItem: Codable, Hashable, Identifiable, Sendable {
    var id: String { slug }
    let title: String
    let slug: String
    let posterUrl: String?
    let type: String?
    let releaseDate: String?
    let averageRating: Double?
}

/// A person in the people directory listing.
nonisolated struct PersonListItem: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let slug: String
    let photoUrl: String?
    let gender: String?
    let birthDate: String?
    let birthPlace: String?
    let nationality: String?
    let isFeatured: Bool?
    let contentCount: Int?
    let knownFor: [KnownForItem]?
}
