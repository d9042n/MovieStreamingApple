//
//  PersonFilmCard.swift
//  MovieStreamingApple
//
//  Individual film card in the filmography grid.
//  Extracted from PersonDetailView for reusability and readability.
//

import SwiftUI

struct PersonFilmCard: View {
    let film: FilmographyItem

    @Environment(\.themeManager) private var themeManager

    var body: some View {
        let statusInfo = PersonDetailViewModel.getStatusInfo(film.status)
        let year = film.releaseDate.flatMap { String($0.prefix(4)) }

        NavigationLink(value: ContentDestination(
            slug: film.slug,
            type: film.type == "series" ? .series : .movie
        )) {
            VStack(alignment: .leading, spacing: 6) {
                // Poster — container enforces 2:3
                Color.clear
                    .aspectRatio(2 / 3, contentMode: .fit)
                    .overlay(alignment: .top) {
                        ZStack {
                            if let posterUrl = film.posterUrl, let url = URL(string: posterUrl) {
                                AsyncImage(url: url) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                                } placeholder: {
                                    filmPlaceholder
                                }
                            } else {
                                filmPlaceholder
                            }
                        }
                    }
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(ThemeColor.textPrimary.opacity(0.06), lineWidth: 1)
                    )
                    .overlay(alignment: .topLeading) {
                        if let info = statusInfo {
                            statusBadge(info.label, colorKey: info.color)
                                .padding(5)
                        }
                    }
                    .overlay(alignment: .topTrailing) {
                        if film.type == "series" {
                            HStack(spacing: 2) {
                                Image(systemName: AppIcon.tv)
                                    .font(ThemeFont.body(size: 7))
                                    .foregroundStyle(themeManager.colors.highlight)
                                Text("Series")
                                    .font(ThemeFont.body(size: 7, weight: .bold))
                                    .textCase(.uppercase)
                            }
                            .foregroundStyle(ThemeColor.textPrimary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                            .padding(5)
                        }
                    }

                // Title (fixed height for grid alignment)
                Text(film.title)
                    .font(ThemeFont.body(size: 12, weight: .bold))
                    .foregroundStyle(ThemeColor.textPrimary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, minHeight: 32, alignment: .topLeading)

                // Year + rating (fixed height row)
                HStack(spacing: 4) {
                    if let year {
                        Text(year)
                            .font(ThemeFont.body(size: 10))
                            .foregroundStyle(ThemeColor.textMuted)
                    }
                    if let rating = film.averageRating, rating > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: AppIcon.starFill)
                                .font(ThemeFont.body(size: 7))
                                .foregroundStyle(themeManager.colors.highlight)
                            Text(String(format: "%.1f", rating))
                                .font(ThemeFont.body(size: 10))
                                .foregroundStyle(themeManager.colors.highlight)
                        }
                    }
                    if film.type == "series", let count = film.episodeCount, count > 1 {
                        HStack(spacing: 2) {
                            Image(systemName: AppIcon.playCircle)
                                .font(ThemeFont.body(size: 7))
                            Text("\(count) tập")
                                .font(ThemeFont.body(size: 9))
                        }
                        .foregroundStyle(ThemeColor.textMuted)
                    }
                    Spacer()
                }
                .frame(height: 14)

                // Character name (fixed height slot)
                Text(film.characterName.map { "vai \($0)" } ?? " ")
                    .font(ThemeFont.body(size: 10))
                    .foregroundStyle(film.characterName != nil ? themeManager.colors.link : .clear)
                    .lineLimit(1)
                    .frame(height: 14, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(film.title), \(year ?? ""), \(film.characterName.map { "vai \($0)" } ?? "")"
        )
    }

    // MARK: - Sub-views

    private var filmPlaceholder: some View {
        ZStack {
            ThemeColor.textPrimary.opacity(0.03)
            Image(systemName: AppIcon.film)
                .font(ThemeFont.display(size: 22))
                .foregroundStyle(ThemeColor.textMuted.opacity(0.2))
        }
    }

    private func statusBadge(_ label: String, colorKey: String) -> some View {
        let color: Color = switch colorKey {
        case "highlight": themeManager.colors.highlight
        case "brand": themeManager.colors.brand
        default: .secondary
        }

        return Text(label.uppercased())
            .font(ThemeFont.body(size: 8, weight: .bold))
            .tracking(0.5)
            .foregroundStyle(ThemeColor.textPrimary)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
