//
//  PlayerTrailerModal.swift
//  MovieStreamingApple
//
//  Modal sheet to play trailer videos.
//  Supports YouTube URLs (opens Safari) and direct video URLs (plays inline).
//

import SwiftUI
import AVKit

struct PlayerTrailerModal: View {
    let trailerURL: String
    let contentTitle: String

    @Environment(\.dismiss) private var dismiss
    @Environment(\.themeManager) private var themeManager
    @State private var player: AVPlayer?

    var body: some View {
        NavigationStack {
            ZStack {
                ThemeColor.bgBase.ignoresSafeArea()

                if isYouTubeURL {
                    youtubeContent
                } else {
                    nativePlayer
                }
            }
            .navigationTitle("Trailer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Đóng") {
                        player?.pause()
                        dismiss()
                    }
                    .foregroundStyle(ThemeColor.textPrimary)
                }
            }
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        }
        .presentationDetents([.large])
        .onDisappear {
            player?.pause()
            player?.replaceCurrentItem(with: nil)
            player = nil
        }
    }

    // MARK: - YouTube

    private var isYouTubeURL: Bool {
        trailerURL.contains("youtube.com") || trailerURL.contains("youtu.be")
    }

    private var youtubeContent: some View {
        VStack(spacing: 24) {
            Image(systemName: AppIcon.playRectangleFill)
                .font(ThemeFont.display(size: 64))
                .foregroundStyle(themeManager.colors.brand)

            Text(contentTitle)
                .font(ThemeFont.body(size: 16, weight: .semibold))
                .foregroundStyle(ThemeColor.textPrimary)

            Text("Trailer sẽ mở trong Safari")
                .font(ThemeFont.body(size: 14))
                .foregroundStyle(ThemeColor.textMuted)

            Button {
                if let url = URL(string: trailerURL) {
                    UIApplication.shared.open(url)
                }
                dismiss()
            } label: {
                Label("Mở YouTube", systemImage: AppIcon.arrowUpRight2)
                    .font(ThemeFont.body(size: 14, weight: .bold))
                    .foregroundStyle(ThemeColor.textPrimary)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(themeManager.colors.brand, in: Capsule())
            }
        }
    }

    // MARK: - Native Player

    private var nativePlayer: some View {
        Group {
            if let player = player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
            } else {
                ProgressView()
                    .tint(.white)
            }
        }
        .task {
            guard !isYouTubeURL, let url = URL(string: trailerURL) else { return }
            let avPlayer = AVPlayer(url: url)
            // P0-02: Guard against quick dismiss — if task was cancelled
            // while AVPlayer was being created, stop it immediately
            guard !Task.isCancelled else {
                avPlayer.pause()
                return
            }
            player = avPlayer
            avPlayer.play()
        }
    }
}
