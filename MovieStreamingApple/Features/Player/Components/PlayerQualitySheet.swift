//
//  PlayerQualitySheet.swift
//  MovieStreamingApple
//
//  View for selecting video quality/resolution (pushed via NavigationLink).
//

import SwiftUI

struct PlayerQualitySheet: View {
    let availableQualities: [VideoQualityOption]
    let currentQuality: VideoQualityOption
    var onQualityChange: (VideoQualityOption) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.themeManager) private var themeManager

    var body: some View {
        List {
            ForEach(availableQualities) { quality in
                Button {
                    onQualityChange(quality)
                    dismiss()
                } label: {
                    HStack {
                        Text(quality.displayName)
                            .font(ThemeFont.body(size: 16))
                            .foregroundStyle(ThemeColor.textPrimary)

                        Spacer()

                        if currentQuality == quality {
                            Image(systemName: AppIcon.checkmark)
                                .font(ThemeFont.body(size: 16, weight: .semibold))
                                .foregroundStyle(themeManager.colors.brand)
                        }
                    }
                }
            }
        }
        .navigationTitle("Chất lượng video")
        .navigationBarTitleDisplayMode(.inline)
    }
}
