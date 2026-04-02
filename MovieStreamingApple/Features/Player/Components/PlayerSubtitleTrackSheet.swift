//
//  PlayerSubtitleTrackSheet.swift
//  MovieStreamingApple
//
//  View for selecting subtitle track (pushed via NavigationLink from settings).
//  Same pattern as PlaybackRateSheet: List + checkmark for active item.
//

import SwiftUI

struct PlayerSubtitleTrackSheet: View {
    @Bindable var playerVM: VideoPlayerViewModel
    let subtitles: [SubtitleTrack]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.themeManager) private var themeManager

    var body: some View {
        List {
            // Off option
            Button {
                playerVM.disableSubtitles()
                dismiss()
            } label: {
                HStack {
                    Text("Tắt phụ đề")
                        .font(ThemeFont.body(size: 16))
                        .foregroundStyle(ThemeColor.textPrimary)

                    Spacer()

                    if playerVM.selectedSubtitleTrack == nil {
                        Image(systemName: AppIcon.checkmark)
                            .font(ThemeFont.body(size: 16, weight: .semibold))
                            .foregroundStyle(themeManager.colors.brand)
                    }
                }
            }

            // Available tracks
            ForEach(subtitles) { subtitle in
                Button {
                    playerVM.selectSubtitleTrack(subtitle)
                    dismiss()
                } label: {
                    HStack {
                        Text(subtitle.label)
                            .font(ThemeFont.body(size: 16))
                            .foregroundStyle(ThemeColor.textPrimary)

                        if subtitle.isDefault {
                            Text("Mặc định")
                                .font(ThemeFont.body(size: 10, weight: .bold))
                                .foregroundStyle(themeManager.colors.link)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(themeManager.colors.link.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
                        }

                        Spacer()

                        if playerVM.selectedSubtitleTrack?.id == subtitle.id {
                            Image(systemName: AppIcon.checkmark)
                                .font(ThemeFont.body(size: 16, weight: .semibold))
                                .foregroundStyle(themeManager.colors.brand)
                        }
                    }
                }
            }
        }
        .navigationTitle("Phụ đề")
        .navigationBarTitleDisplayMode(.inline)
    }
}
