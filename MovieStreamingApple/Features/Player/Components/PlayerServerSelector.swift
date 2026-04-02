//
//  PlayerServerSelector.swift
//  MovieStreamingApple
//
//  Inline server selection tabs below the player.
//  Netflix/YouTube-inspired compact design.
//

import SwiftUI

struct PlayerServerSelector: View {
    let servers: [StreamingLink]
    let activeIndex: Int
    var onSelect: (Int) -> Void

    @Environment(\.themeManager) private var themeManager

    var body: some View {
        if !servers.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(servers.enumerated()), id: \.element.id) { index, server in
                        let isActive = index == activeIndex
                        let isOnlyServer = servers.count == 1

                        Button {
                            guard !isOnlyServer else { return }
                            onSelect(index)
                        } label: {
                            HStack(spacing: 5) {
                                // Server icon for active
                                if isActive {
                                    Image(systemName: AppIcon.playCircleFill)
                                        .font(ThemeFont.body(size: 12))
                                }

                                Text(server.serverName)
                                    .font(ThemeFont.body(size: 12, weight: .semibold))

                                if server.hasHLS {
                                    Text("HD")
                                        .font(ThemeFont.display(size: 8, weight: .heavy))
                                        .foregroundStyle(isActive ? .white : themeManager.colors.link)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(
                                            (isActive ? ThemeColor.textPrimary.opacity(0.2) : themeManager.colors.link.opacity(0.12)),
                                            in: RoundedRectangle(cornerRadius: 3)
                                        )
                                }
                            }
                            .foregroundStyle(isActive ? .white : .secondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background {
                                if isActive {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(themeManager.colors.brand)
                                } else {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(themeManager.colors.bgCard)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(server.serverName)\(server.hasHLS ? ", HD" : "")")
                        .accessibilityAddTraits(.isButton)
                    }
                }
                .animation(DesignTokens.Animation.quick, value: activeIndex)
            }
        }
    }
}
