//
//  StreamingLink.swift
//  MovieStreamingApple
//
//  Streaming server/link model for video playback.
//  Mirrors the backend `streamingLinks[]` response.
//

import Foundation

/// A single streaming server with HLS and/or embed links.
nonisolated struct StreamingLink: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let serverName: String
    let linkM3u8: String?
    let linkEmbed: String?
    let quality: String?
    let sortOrder: Int?

    /// Whether this server has a native HLS stream.
    var hasHLS: Bool { linkM3u8 != nil && !(linkM3u8?.isEmpty ?? true) }

    /// Whether this server only has an embed link.
    var isEmbedOnly: Bool { !hasHLS && linkEmbed != nil && !(linkEmbed?.isEmpty ?? true) }
}

/// Subtitle track for a movie or episode.
nonisolated struct SubtitleTrack: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let languageCode: String
    let label: String
    let fileUrl: String
    let isDefault: Bool
}
