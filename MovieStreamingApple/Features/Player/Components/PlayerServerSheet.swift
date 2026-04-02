//
//  PlayerServerSheet.swift
//  MovieStreamingApple
//
//  View for selecting streaming server (pushed via NavigationLink from settings).
//  Same pattern as PlaybackRateSheet: List + checkmark for active item.
//

import SwiftUI

struct PlayerServerSheet: View {
    let servers: [StreamingLink]
    let activeIndex: Int
    var onServerChange: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.themeManager) private var themeManager

    var body: some View {
        List {
            ForEach(Array(servers.enumerated()), id: \.element.id) { index, server in
                Button {
                    onServerChange(index)
                    dismiss()
                } label: {
                    HStack {
                        Text(server.serverName)
                            .font(ThemeFont.body(size: 16))
                            .foregroundStyle(ThemeColor.textPrimary)

                        if server.hasHLS {
                            Text("HD")
                                .font(ThemeFont.body(size: 9, weight: .bold))
                                .foregroundStyle(themeManager.colors.link)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(themeManager.colors.link.opacity(0.15), in: RoundedRectangle(cornerRadius: 3))
                        }

                        Spacer()

                        if index == activeIndex {
                            Image(systemName: AppIcon.checkmark)
                                .font(ThemeFont.body(size: 16, weight: .semibold))
                                .foregroundStyle(themeManager.colors.brand)
                        }
                    }
                }
            }
        }
        .navigationTitle("Server")
        .navigationBarTitleDisplayMode(.inline)
    }
}
