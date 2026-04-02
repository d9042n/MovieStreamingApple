//
//  WatchingCardView.swift
//  MovieStreamingApple
//
//  Card with progress bar overlay for the "Continue Watching" carousel.
//  Shows poster (fallback backdrop), progress, title, and episode info.
//  Uses WatchDisplayData (API-fetched rich data).
//

import SwiftUI

struct WatchingCardView: View {
    let displayData: WatchDisplayData
    @Environment(\.themeManager) private var themeManager

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            // MARK: - Poster with Progress Bar
            posterWithProgress

            // MARK: - Title (fixed height for grid consistency)
            Text(displayData.title)
                .font(ThemeFont.display(size: 15, weight: .semibold))
                .foregroundStyle(themeManager.colors.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, minHeight: 36, alignment: .topLeading)

            // MARK: - Meta Info (fixed height row)
            HStack(spacing: DesignTokens.Spacing.sm) {
                if let meta = metaText {
                    Text(meta)
                        .font(ThemeFont.body(size: 11))
                        .foregroundStyle(themeManager.colors.textMuted)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: displayData.entry.contentType == .series ? "tv" : "film")
                    .font(ThemeFont.body(size: 10))
                    .foregroundStyle(themeManager.colors.textMuted)
            }
            .frame(height: 16)
        }
        .frame(width: DesignTokens.PosterSize.railWidth)
    }

    // MARK: - Poster + Progress

    private var posterWithProgress: some View {
        Color.clear
            .aspectRatio(2 / 3, contentMode: .fit)
            .overlay(alignment: .top) {
                AsyncImage(url: displayData.cardImageUrl) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    case .failure:
                        posterPlaceholder
                    default:
                        posterShimmer
                    }
                }
            }
            // Progress bar overlay at bottom
            .overlay(alignment: .bottom) {
                if displayData.entry.progress > 0.01 && !displayData.entry.isFinished {
                    progressBar
                }
            }
            // Remaining time badge
            .overlay(alignment: .topTrailing) {
                if let remaining = displayData.remainingTimeFormatted {
                    Text(remaining)
                        .font(ThemeFont.display(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(themeManager.colors.brand.opacity(0.85))
                        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.small))
                        .padding(DesignTokens.Spacing.sm)
                }
            }
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.poster))
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(ThemeColor.bgBase.opacity(0.5))
                    .frame(height: 3)

                Rectangle()
                    .fill(themeManager.colors.brand)
                    // UX-05: Ensure minimum visible width at very low progress
                    .frame(width: max(4, geo.size.width * displayData.entry.progress), height: 3)
            }
        }
        .frame(height: 3)
    }

    // MARK: - Meta Text

    private var metaText: String? {
        if displayData.entry.contentType == .series {
            var parts: [String] = []
            if let sn = displayData.entry.seasonNumber {
                parts.append("Phần \(sn)")
            }
            if let ep = displayData.entry.episodeNumber {
                parts.append("Tập \(ep)")
            }
            return parts.isEmpty ? nil : parts.joined(separator: " · ")
        }
        return displayData.remainingTimeFormatted
    }

    // MARK: - Placeholders

    private var posterPlaceholder: some View {
        Rectangle()
            .fill(.quaternary)
            .aspectRatio(2 / 3, contentMode: .fit)
            .overlay {
                Image(systemName: AppIcon.film)
                    .font(ThemeFont.display(size: 28, weight: .bold))
                    .foregroundStyle(themeManager.colors.textMuted)
            }
    }

    private var posterShimmer: some View {
        Rectangle()
            .fill(.quaternary)
            .aspectRatio(2 / 3, contentMode: .fit)
            .overlay { ProgressView() }
    }
}
