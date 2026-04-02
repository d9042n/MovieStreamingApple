//
//  PlayerSettingsSheet.swift
//  MovieStreamingApple
//
//  Settings bottom sheet for the player: playback rate, subtitles, quality.
//  Shown from the "gear" button on the player HUD.
//
//  All selections use NavigationLink → sub-page pattern for consistency.
//

import SwiftUI

struct PlayerSettingsSheet: View {
    @Bindable var playerVM: VideoPlayerViewModel
    let subtitles: [SubtitleTrack]
    let servers: [StreamingLink]
    let activeServerIndex: Int

    var onServerChange: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.themeManager) private var themeManager

    var body: some View {
        NavigationStack {
            List {
                // === Playback Speed ===
                Section {
                    NavigationLink {
                        PlayerPlaybackRateSheet(
                            currentRate: playerVM.playbackRate,
                            onRateChange: { rate in
                                playerVM.setPlaybackRate(rate)
                            }
                        )
                    } label: {
                        HStack {
                            Label("Tốc độ phát", systemImage: AppIcon.gaugeNeedle)
                            Spacer()
                            Text(rateLabel)
                                .foregroundStyle(ThemeColor.textMuted)
                        }
                    }
                } header: {
                    Text("Phát lại")
                }

                // === Skip Intro & Outro ===
                Section {
                    NavigationLink {
                        PlayerSkipContentSheet(settings: playerVM.skipSettings)
                    } label: {
                        HStack {
                            Label("Bỏ qua intro & outro", systemImage: AppIcon.forwardFrame)
                            Spacer()
                            Text(playerVM.skipSettings.summaryLabel)
                                .foregroundStyle(ThemeColor.textMuted)
                                .lineLimit(1)
                        }
                    }
                } header: {
                    Text("Bỏ qua nội dung")
                }

                // === Quality ===
                if playerVM.availableQualities.count > 1 {
                    Section {
                        NavigationLink {
                            PlayerQualitySheet(
                                availableQualities: playerVM.availableQualities,
                                currentQuality: playerVM.selectedQuality,
                                onQualityChange: { quality in
                                    playerVM.setVideoQuality(quality)
                                }
                            )
                        } label: {
                            HStack {
                                Label("Chất lượng video", systemImage: AppIcon.sparklesTv)
                                Spacer()
                                Text(playerVM.selectedQuality.displayName)
                                    .foregroundStyle(ThemeColor.textMuted)
                                    .lineLimit(1)
                            }
                        }
                    } header: {
                        Text("Chất lượng")
                    }
                }

                // === Subtitles ===
                if !subtitles.isEmpty {
                    Section {
                        // Subtitle track selection → sub-page
                        NavigationLink {
                            PlayerSubtitleTrackSheet(
                                playerVM: playerVM,
                                subtitles: subtitles
                            )
                        } label: {
                            HStack {
                                Label("Phụ đề", systemImage: AppIcon.captionsBubble)
                                Spacer()
                                Text(subtitleLabel)
                                    .foregroundStyle(ThemeColor.textMuted)
                                    .lineLimit(1)
                            }
                        }

                        // Subtitle appearance → sub-page
                        NavigationLink {
                            PlayerSubtitleAppearanceSheet(settings: playerVM.subtitleSettings)
                        } label: {
                            HStack {
                                Label("Kiểu phụ đề", systemImage: AppIcon.textformatAbc)
                                Spacer()
                                subtitlePreviewBadge
                            }
                        }
                    } header: {
                        Text("Phụ đề (\(subtitles.count))")
                    }
                }

                // === Server ===
                if servers.count > 1 {
                    Section {
                        NavigationLink {
                            PlayerServerSheet(
                                servers: servers,
                                activeIndex: activeServerIndex,
                                onServerChange: onServerChange
                            )
                        } label: {
                            HStack {
                                Label("Server", systemImage: AppIcon.serverRack)
                                Spacer()
                                HStack(spacing: 4) {
                                    Text(activeServerName)
                                        .foregroundStyle(ThemeColor.textMuted)
                                    if activeServerHasHLS {
                                        Text("HD")
                                            .font(ThemeFont.body(size: 9, weight: .bold))
                                            .foregroundStyle(themeManager.colors.link)
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 2)
                                            .background(themeManager.colors.link.opacity(0.15), in: RoundedRectangle(cornerRadius: 3))
                                    }
                                }
                            }
                        }
                    } header: {
                        Text("Nguồn phát")
                    }
                }
            }
            .navigationTitle("Cài đặt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Xong") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Helpers

    /// Shows a mini preview of the current subtitle style settings.
    private var subtitlePreviewBadge: some View {
        let settings = playerVM.subtitleSettings
        return Text("Abc")
            .font(settings.fontFamily.font(size: 11, weight: settings.textBold ? .bold : .regular))
            .foregroundStyle(settings.textColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(settings.bgColor, in: RoundedRectangle(cornerRadius: 4))
            .modifier(EdgeStyleModifier(edgeStyle: settings.edgeStyle))
    }

    private var rateLabel: String {
        playerVM.playbackRate == 1.0 ? "Bình thường" : "\(String(format: "%.2g", playerVM.playbackRate))x"
    }

    private var subtitleLabel: String {
        if let track = playerVM.selectedSubtitleTrack {
            return track.label
        }
        return "Tắt"
    }

    private var activeServerName: String {
        guard activeServerIndex >= 0, activeServerIndex < servers.count else { return "" }
        return servers[activeServerIndex].serverName
    }

    private var activeServerHasHLS: Bool {
        guard activeServerIndex >= 0, activeServerIndex < servers.count else { return false }
        return servers[activeServerIndex].hasHLS
    }
}
