//
//  PersonBannerView.swift
//  MovieStreamingApple
//
//  Person detail banner — uses shared CrossfadeBannerView
//  with filmography backdrop URLs.
//

import SwiftUI

struct PersonBannerView: View {
    let backdropURLs: [URL]

    var body: some View {
        CrossfadeBannerView(
            imageURLs: backdropURLs,
            imageOpacity: 0.6
        )
    }
}
