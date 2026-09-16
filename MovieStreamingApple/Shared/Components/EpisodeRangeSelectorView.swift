//
//  EpisodeRangeSelectorView.swift
//  MovieStreamingApple
//
//  Horizontal scrolling chip selector for episode ranges (e.g., 1-100, 101-200)
//  Used in ContentDetail and Player for long-running series like Conan / One Piece.
//

import SwiftUI

struct EpisodeRangeSelectorView: View {
    let totalEpisodes: Int
    let activeFrom: Int
    var chunkSize: Int = 100
    var onSelectRange: (Int, Int) -> Void

    @Environment(\.themeManager) private var themeManager

    private var chunkCount: Int {
        guard totalEpisodes > 0, chunkSize > 0 else { return 0 }
        return (totalEpisodes + chunkSize - 1) / chunkSize
    }

    var body: some View {
        if totalEpisodes > chunkSize {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(0..<chunkCount, id: \.self) { idx in
                        let from = idx * chunkSize + 1
                        let to = min((idx + 1) * chunkSize, totalEpisodes)
                        let isSelected = activeFrom == from

                        Button {
                            onSelectRange(from, to)
                        } label: {
                            Text("\(from) - \(to)")
                                .font(ThemeFont.body(size: 12, weight: isSelected ? .bold : .medium))
                                .foregroundStyle(isSelected ? .white : ThemeColor.textPrimary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    isSelected
                                        ? themeManager.colors.brand
                                        : ThemeColor.textPrimary.opacity(0.08),
                                    in: RoundedRectangle(cornerRadius: 8)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }
        }
    }
}
