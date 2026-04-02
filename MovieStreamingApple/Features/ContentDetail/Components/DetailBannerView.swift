//
//  DetailBannerView.swift
//  MovieStreamingApple
//
//  Immersive full-width backdrop banner leveraging the shared
//  CrossfadeBannerView. Handles URL resolution from media gallery
//  with fallback to single backdrop/poster.
//

import SwiftUI

struct DetailBannerView: View {
    let backdropUrl: String?
    let posterUrl: String?
    let backdrops: [MediaItem]

    /// All image URLs: media backdrops first, then fallback to single backdrop/poster.
    private var imageURLs: [URL] {
        // Prefer media gallery backdrops (max 8)
        let mediaURLs = backdrops
            .compactMap { URL(string: $0.url) }

        if !mediaURLs.isEmpty { return Array(mediaURLs.prefix(8)) }

        // Fallback: single backdrop or poster
        if let b = backdropUrl, !b.trimmingCharacters(in: .whitespaces).isEmpty,
           let url = URL(string: b) {
            return [url]
        }
        if let p = posterUrl, !p.trimmingCharacters(in: .whitespaces).isEmpty,
           let url = URL(string: p) {
            return [url]
        }
        return []
    }

    var body: some View {
        CrossfadeBannerView(imageURLs: imageURLs)
    }
}

// MARK: - Preview

#Preview("Detail Banner") {
    DetailBannerView(
        backdropUrl: "https://image.tmdb.org/t/p/w1280/4XM8DUTQb3lhLemJC51Jx4a2EuA.jpg",
        posterUrl: nil,
        backdrops: []
    )
    .preferredColorScheme(.dark)
}
