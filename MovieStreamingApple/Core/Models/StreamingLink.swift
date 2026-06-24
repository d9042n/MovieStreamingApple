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

    /// Whether this server has a direct video stream (HLS or progressive MP4).
    var hasDirectStream: Bool {
        let m3u8 = linkM3u8 ?? ""
        let embed = linkEmbed ?? ""
        return !m3u8.isEmpty || !embed.isEmpty
    }

    /// Backward compat alias — true when linkM3u8 is populated.
    var hasHLS: Bool { linkM3u8 != nil && !(linkM3u8?.isEmpty ?? true) }

    /// Whether the direct URL is HLS format (.m3u8).
    var isHLSStream: Bool {
        guard let url = linkM3u8, !url.isEmpty else { return false }
        return url.lowercased().contains(".m3u8")
    }
}

/// Subtitle track for a movie or episode.
nonisolated struct SubtitleTrack: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let languageCode: String
    let label: String
    let fileUrl: String
    let isDefault: Bool

    enum CodingKeys: String, CodingKey {
        case id, languageCode, label, fileUrl, isDefault
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // Tolerate omitted fields (e.g. a missing `label` or `is_default`) so one
        // sparse subtitle row can't fail the entire episode/watch-detail decode.
        id = (try? c.decodeIfPresent(String.self, forKey: .id)) ?? UUID().uuidString
        languageCode = (try? c.decodeIfPresent(String.self, forKey: .languageCode)) ?? ""
        label = (try? c.decodeIfPresent(String.self, forKey: .label)) ?? ""
        fileUrl = (try? c.decodeIfPresent(String.self, forKey: .fileUrl)) ?? ""
        isDefault = (try? c.decodeIfPresent(Bool.self, forKey: .isDefault)) ?? false
    }
}
