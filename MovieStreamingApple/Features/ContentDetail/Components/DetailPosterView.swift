//
//  DetailPosterView.swift
//  MovieStreamingApple
//
//  Centered poster card with action buttons.
//  Mirrors the website's left column: poster + play/trailer/bookmark buttons.
//  On mobile, the poster is centered (220px width as per mobile layout).
//

import SwiftUI

struct DetailPosterView: View {
    let content: Content
    let statusInfo: (label: String, color: StatusColor)?

    @State private var showTrailer = false

    @Environment(\.themeManager) private var themeManager

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            // MARK: - Poster Image
            ZStack(alignment: .topLeading) {
                CachedAsyncImage(url: posterURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 220, height: 330, alignment: .top)
                } placeholder: {
                    posterShimmer
                }
                .frame(width: 220, height: 330)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.5), radius: 20, y: 20)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(ThemeColor.textPrimary.opacity(0.1), lineWidth: 1)
                )

                // Status badge
                if let statusInfo {
                    statusBadge(statusInfo)
                        .padding(12)
                }
            }

            // MARK: - Action Buttons
            VStack(spacing: DesignTokens.Spacing.md) {
                // Xem Phim (Watch)
                NavigationLink(
                    value: PlayerDestination(
                        slug: content.effectiveSlug,
                        type: content.type ?? .movie
                    )
                ) {
                    HStack(spacing: 8) {
                        Image(systemName: AppIcon.playFill)
                            .font(ThemeFont.body(size: 13))
                        Text("XEM PHIM")
                            .font(ThemeFont.body(size: 13, weight: .bold))
                            .tracking(2)
                    }
                    .foregroundStyle(ThemeColor.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [themeManager.colors.brand, themeManager.colors.brand.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: themeManager.colors.brand.opacity(0.3), radius: 10, y: 4)
                }

                // Xem Trailer
                Button {
                    if content.trailerUrl != nil {
                        showTrailer = true
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: AppIcon.play)
                            .font(ThemeFont.body(size: 13))
                            .opacity(0.7)
                        Text("XEM TRAILER")
                            .font(ThemeFont.body(size: 13, weight: .bold))
                            .tracking(2)
                    }
                    .foregroundStyle(content.trailerUrl != nil ? .primary : .tertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(ThemeColor.textPrimary.opacity(0.1), lineWidth: 1)
                    )
                }
                .disabled(content.trailerUrl == nil)
                .opacity(content.trailerUrl != nil ? 1 : 0.5)

                // MARK: [UNIMPLEMENTED] Bookmark button — hidden for App Store review
                // No bookmark API/backend implemented yet
                // Button {
                //     // No action — feature not yet implemented
                // } label: {
                //     HStack(spacing: 8) {
                //         Image(systemName: AppIcon.bookmark)
                //             .font(ThemeFont.body(size: 13))
                //         Text("ĐÁNH DẤU")
                //             .font(ThemeFont.body(size: 13, weight: .bold))
                //             .tracking(2)
                //     }
                //     .foregroundStyle(.tertiary)
                //     .frame(maxWidth: .infinity)
                //     .padding(.vertical, 14)
                //     .background(.clear)
                //     .clipShape(RoundedRectangle(cornerRadius: 12))
                //     .overlay(
                //         RoundedRectangle(cornerRadius: 12)
                //             .stroke(ThemeColor.textPrimary.opacity(0.08), lineWidth: 1)
                //     )
                // }
                // .disabled(true)
                // .opacity(0.5)
                // .accessibilityHint("Tính năng đang phát triển")
            }
            .frame(width: 220)
        }
        .sheet(isPresented: $showTrailer) {
            if let trailerURL = content.trailerUrl {
                PlayerTrailerModal(trailerURL: trailerURL, contentTitle: content.title)
            }
        }
    }

    // MARK: - Helpers

    private var posterURL: URL? {
        guard let urlString = content.posterUrl else { return nil }
        return URL(string: urlString)
    }

    @ViewBuilder
    private func statusBadge(_ info: (label: String, color: StatusColor)) -> some View {
        Text(info.label.uppercased())
            .font(ThemeFont.body(size: 10, weight: .heavy))
            .tracking(1)
            .foregroundStyle(ThemeColor.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background {
                switch info.color {
                case .green: themeManager.colors.highlight
                case .blue: themeManager.colors.link
                case .orange: themeManager.colors.brand
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(radius: 4)
    }

    private var posterPlaceholder: some View {
        Rectangle()
            .fill(Color(white: 0.15))
            .aspectRatio(2 / 3, contentMode: .fit)
            .overlay {
                Image(systemName: AppIcon.film)
                    .font(ThemeFont.display(size: 36))
                    .foregroundStyle(.tertiary)
            }
    }

    private var posterShimmer: some View {
        Rectangle()
            .fill(Color(white: 0.12))
            .aspectRatio(2 / 3, contentMode: .fit)
            .overlay { ProgressView() }
    }
}
