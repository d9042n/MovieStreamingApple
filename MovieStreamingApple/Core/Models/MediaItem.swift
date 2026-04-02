//
//  MediaItem.swift
//  MovieStreamingApple
//
//  Media gallery items (backdrops, posters, videos) for content detail.
//

import Foundation

/// A media gallery item (photo or video).
nonisolated struct MediaItem: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let type: String  // "photo" or "video"
    let url: String
    let title: String
    let sortOrder: Int

    /// Whether this media item is a backdrop image.
    var isBackdrop: Bool {
        title.localizedCaseInsensitiveContains("backdrop")
    }

    /// Whether this media item is a poster image.
    var isPoster: Bool {
        title.localizedCaseInsensitiveContains("poster")
    }
}
