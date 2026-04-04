//
//  PlayerRelatedGrid.swift
//  MovieStreamingApple
//
//  Grid of related content cards below the Watch page info.
//  Each card navigates to ContentDetailView.
//

import SwiftUI

struct PlayerRelatedGrid: View {
    let contents: [Content]

    @Environment(\.themeManager) private var themeManager

    var body: some View {
        if !contents.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack(spacing: 6) {
                    Image(systemName: AppIcon.sparkles)
                        .font(ThemeFont.body(size: 11))
                        .foregroundStyle(themeManager.colors.brand)
                    Text("Phim Liên Quan")
                        .font(ThemeFont.display(size: 13, weight: .bold))
                        .textCase(.uppercase)
                        .foregroundStyle(ThemeColor.textMuted)
                }

                // Grid
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 10, alignment: .top),
                    GridItem(.flexible(), spacing: 10, alignment: .top),
                    GridItem(.flexible(), spacing: 10, alignment: .top)
                ], spacing: 12) {
                    ForEach(contents.prefix(9)) { content in
                        NavigationLink(value: ContentDestination(
                            slug: content.effectiveSlug,
                            type: content.type ?? .movie
                        )) {
                            relatedCard(content)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func relatedCard(_ content: Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // Poster — container enforces 2:3
            Color.clear
                .aspectRatio(2 / 3, contentMode: .fit)
                .overlay(alignment: .top) {
                    AsyncImage(url: URL(string: content.posterUrl ?? "")) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        default:
                            Rectangle()
                                .fill(.gray.opacity(0.1))
                                .overlay {
                                    Image(systemName: AppIcon.film)
                                        .foregroundStyle(ThemeColor.textMuted)
                                }
                        }
                    }
                }
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(alignment: .topTrailing) {
                // Quality badge
                if let quality = content.streamingMeta?.quality {
                    Text(quality)
                        .font(ThemeFont.display(size: 8, weight: .bold))
                        .foregroundStyle(ThemeColor.textPrimary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(themeManager.colors.brand, in: RoundedRectangle(cornerRadius: 3))
                        .padding(4)
                }
            }

            // Title (fixed height for grid alignment)
            Text(content.title)
                .font(ThemeFont.body(size: 11, weight: .bold))
                .lineLimit(2)
                .frame(maxWidth: .infinity, minHeight: 28, alignment: .topLeading)

            // Rating (fixed height row)
            HStack(spacing: 2) {
                if let rating = content.averageRating, rating > 0 {
                    Image(systemName: AppIcon.starFill)
                        .font(ThemeFont.body(size: 8))
                        .foregroundStyle(themeManager.colors.highlight)
                    Text(String(format: "%.1f", rating))
                        .font(ThemeFont.body(size: 9, weight: .bold))
                        .foregroundStyle(ThemeColor.textMuted)
                }
                Spacer()
            }
            .frame(height: 12)
        }
    }
}
