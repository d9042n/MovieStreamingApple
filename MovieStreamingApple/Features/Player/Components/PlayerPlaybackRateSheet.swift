//
//  PlayerPlaybackRateSheet.swift
//  MovieStreamingApple
//
//  View for selecting playback speed (pushed via NavigationLink).
//

import SwiftUI

struct PlayerPlaybackRateSheet: View {
    let currentRate: Float
    var onRateChange: (Float) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.themeManager) private var themeManager

    private let rates: [(label: String, value: Float)] = [
        ("0.25x", 0.25),
        ("0.5x", 0.5),
        ("0.75x", 0.75),
        ("Bình thường", 1.0),
        ("1.25x", 1.25),
        ("1.5x", 1.5),
        ("1.75x", 1.75),
        ("2x", 2.0),
    ]

    var body: some View {
        List {
            ForEach(rates, id: \.value) { rate in
                Button {
                    onRateChange(rate.value)
                    dismiss()
                } label: {
                    HStack {
                        Text(rate.label)
                            .font(ThemeFont.body(size: 16))
                            .foregroundStyle(ThemeColor.textPrimary)

                        Spacer()

                        if currentRate == rate.value {
                            Image(systemName: AppIcon.checkmark)
                                .font(ThemeFont.body(size: 16, weight: .semibold))
                                .foregroundStyle(themeManager.colors.brand)
                        }
                    }
                }
            }
        }
        .navigationTitle("Tốc độ phát")
        .navigationBarTitleDisplayMode(.inline)
    }
}
