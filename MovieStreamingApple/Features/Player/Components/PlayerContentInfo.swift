//
//  PlayerContentInfo.swift
//  MovieStreamingApple
//
//  Content info section below the player, matching the web WatchPage layout:
//  Title → Meta row → Streaming + Genre badges → Description + Info Grid + Cast
//  all inside one card container.
//

import SwiftUI

struct PlayerContentInfo: View {
    let content: Content?
    let displayTitle: String
    let displayDescription: String
    let isSeries: Bool
    let currentEpisode: Episode?
    let directors: [Person]
    let actors: [CastMember]
    let bookmarkCount: Int?

    @State private var isDescriptionExpanded = false
    @State private var showAllInfo = false
    @State private var showAllCast = false

    @Environment(\.themeManager) private var themeManager

    var body: some View {
        if let content = content {
            VStack(alignment: .leading, spacing: 12) {
                // Title + original title
                titleSection(content)

                // Metadata pills row (rating, year, duration, views)
                metaRow(content)

                // Streaming quality + genre badges
                streamingAndGenreBadges(content)

                // Card: Description + Info Grid + Cast
                infoCard(content)
            }
        }
    }

    // MARK: - Title

    @ViewBuilder
    private func titleSection(_ content: Content) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(displayTitle)
                .font(ThemeFont.display(size: 20, weight: .bold))
                .lineLimit(2)

            if let original = content.originalTitle, original != content.title {
                Text(original)
                    .font(ThemeFont.body(size: 12))
                    .foregroundStyle(ThemeColor.textMuted)
                    .italic()
            }
        }
    }

    // MARK: - Meta Row (inline badges like web)

    @ViewBuilder
    private func metaRow(_ content: Content) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // Rating
                if let rating = content.averageRating, rating > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: AppIcon.starFill)
                            .font(ThemeFont.body(size: 11))
                            .foregroundStyle(themeManager.colors.highlight)
                        Text(String(format: "%.1f", rating))
                            .font(ThemeFont.body(size: 12, weight: .bold))
                        if let count = content.ratingCount, count > 0 {
                            Text("(\(formatCount(count)))")
                                .font(ThemeFont.display(size: 10))
                                .foregroundStyle(ThemeColor.textMuted)
                        }
                    }
                }

                // Year
                if let year = content.releaseYear {
                    HStack(spacing: 3) {
                        Image(systemName: AppIcon.calendar)
                            .font(ThemeFont.body(size: 10))
                        Text("\(year)")
                            .font(ThemeFont.body(size: 12))
                    }
                    .foregroundStyle(ThemeColor.textMuted)
                }

                // Duration
                if !isSeries, let duration = content.formattedDuration {
                    HStack(spacing: 3) {
                        Image(systemName: AppIcon.clock)
                            .font(ThemeFont.body(size: 10))
                        Text(duration)
                            .font(ThemeFont.body(size: 12))
                    }
                    .foregroundStyle(ThemeColor.textMuted)
                } else if isSeries, let ep = currentEpisode, let duration = ep.formattedDuration {
                    HStack(spacing: 3) {
                        Image(systemName: AppIcon.clock)
                            .font(ThemeFont.body(size: 10))
                        Text(duration)
                            .font(ThemeFont.body(size: 12))
                    }
                    .foregroundStyle(ThemeColor.textMuted)
                }

                // Content rating
                if let rating = content.contentRating {
                    Text(rating)
                        .font(ThemeFont.display(size: 10, weight: .bold))
                        .foregroundStyle(ThemeColor.textMuted)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .overlay {
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(ThemeColor.textMuted.opacity(0.4), lineWidth: 1)
                        }
                }

                // Views
                if let views = content.formattedViews {
                    HStack(spacing: 3) {
                        Image(systemName: AppIcon.eye)
                            .font(ThemeFont.body(size: 10))
                        Text(views)
                            .font(ThemeFont.body(size: 12))
                    }
                    .foregroundStyle(ThemeColor.textMuted)
                }
            }
        }
    }

    // MARK: - Streaming + Genre Badges (combined row like web)

    @ViewBuilder
    private func streamingAndGenreBadges(_ content: Content) -> some View {
        let hasStreamingBadges = content.streamingMeta != nil
        let hasGenres = content.genres != nil && !(content.genres?.isEmpty ?? true)

        if hasStreamingBadges || hasGenres {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    // Streaming quality badges
                    if let meta = content.streamingMeta {
                        if let quality = meta.quality {
                            streamBadge(quality, color: themeManager.colors.brand)
                        }
                        if let lang = meta.language {
                            streamBadge(lang, color: themeManager.colors.link)
                        }
                        if let epCurrent = meta.episodeCurrent {
                            streamBadge(epCurrent, color: themeManager.colors.highlight)
                        }

                        // Divider between stream badges and genres
                        if hasGenres {
                            Rectangle()
                                .fill(.secondary.opacity(0.3))
                                .frame(width: 1, height: 18)
                        }
                    }

                    // Genre badges
                    if let genres = content.genres {
                        ForEach(genres.prefix(4), id: \.name) { genre in
                            Text(genre.name)
                                .font(ThemeFont.body(size: 11, weight: .medium))
                                .foregroundStyle(ThemeColor.textMuted)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(themeManager.colors.bgCard, in: RoundedRectangle(cornerRadius: 6))
                        }
                    }
                }
            }
        }
    }

    private func streamBadge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(ThemeFont.display(size: 10, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(color.opacity(0.2), lineWidth: 1)
            }
    }

    // MARK: - Info Card (Description + Info Grid + Cast — single card like web)

    @ViewBuilder
    private func infoCard(_ content: Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Description
            descriptionSection
                .padding(14)

            // Info Grid
            let items = buildInfoItems(content)
            if !items.isEmpty {
                Rectangle()
                    .fill(themeManager.colors.border)
                    .frame(height: 0.5)
                    .padding(.horizontal, 10)

                infoGrid(items: items)
                    .padding(14)
            }

            // Cast Section (inside same card)
            if !actors.isEmpty {
                Rectangle()
                    .fill(themeManager.colors.border)
                    .frame(height: 0.5)
                    .padding(.horizontal, 10)

                castSection
                    .padding(14)
            }
        }
        .background(themeManager.colors.bgCard, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Description (expandable)

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !displayDescription.isEmpty {
                Text(displayDescription)
                    .font(ThemeFont.body(size: 14))
                    .foregroundStyle(ThemeColor.textMuted)
                    .lineLimit(isDescriptionExpanded ? nil : 3)
                    .lineSpacing(2)

                if displayDescription.count > 120 {
                    Button {
                        withAnimation(DesignTokens.Animation.quick) {
                            isDescriptionExpanded.toggle()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(isDescriptionExpanded ? "Thu gọn" : "Xem thêm")
                                .font(ThemeFont.body(size: 12, weight: .semibold))
                            Image(systemName: isDescriptionExpanded ? AppIcon.chevronUp : AppIcon.chevronDown)
                                .font(ThemeFont.body(size: 9, weight: .semibold))
                        }
                        .foregroundStyle(themeManager.colors.link)
                    }
                }
            } else {
                Text("Chưa có mô tả cho nội dung này.")
                    .font(ThemeFont.body(size: 14))
                    .foregroundStyle(.tertiary)
                    .italic()
            }
        }
    }

    // MARK: - Info Grid (bento-style like web)

    @ViewBuilder
    private func infoGrid(items: [InfoGridItem]) -> some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8),
        ], spacing: 8) {
            // Director cell — tappable if slug exists
            if !directors.isEmpty {
                directorCell
            }

            ForEach(items, id: \.label) { item in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: item.icon)
                            .font(ThemeFont.body(size: 10))
                        Text(item.label)
                            .font(ThemeFont.display(size: 9, weight: .bold))
                            .textCase(.uppercase)
                            .tracking(0.5)
                    }
                    .foregroundStyle(ThemeColor.textMuted)

                    Text(item.value)
                        .font(ThemeFont.body(size: 12, weight: .medium))
                        .foregroundStyle(ThemeColor.textPrimary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(themeManager.colors.border, in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    /// Director info cell with tappable names
    private var directorCell: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: AppIcon.megaphone)
                    .font(ThemeFont.body(size: 10))
                Text("Đạo diễn")
                    .font(ThemeFont.display(size: 9, weight: .bold))
                    .textCase(.uppercase)
                    .tracking(0.5)
            }
            .foregroundStyle(ThemeColor.textMuted)

            // Tappable director names
            HStack(spacing: 4) {
                ForEach(Array(directors.prefix(2).enumerated()), id: \.offset) { index, director in
                    if index > 0 {
                        Text(",")
                            .font(ThemeFont.body(size: 12, weight: .medium))
                            .foregroundStyle(ThemeColor.textPrimary)
                    }
                    if let slug = director.slug, !slug.isEmpty {
                        NavigationLink(value: PersonDestination(slug: slug)) {
                            Text(director.name ?? "")
                                .font(ThemeFont.body(size: 12, weight: .bold))
                                .foregroundStyle(themeManager.colors.link)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text(director.name ?? "")
                            .font(ThemeFont.body(size: 12, weight: .medium))
                            .foregroundStyle(ThemeColor.textPrimary)
                    }
                }
            }
            .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(themeManager.colors.border, in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Cast Section (inside card)

    private var castSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: AppIcon.person2)
                        .font(ThemeFont.body(size: 12))
                        .foregroundStyle(themeManager.colors.link)
                    Text("Diễn viên")
                        .font(ThemeFont.display(size: 12, weight: .bold))
                        .textCase(.uppercase)
                        .tracking(0.5)
                    Text("(\(actors.count))")
                        .font(ThemeFont.body(size: 10))
                        .foregroundStyle(ThemeColor.textMuted)
                }

                Spacer()

                if actors.count > 6 {
                    Button {
                        withAnimation { showAllCast.toggle() }
                    } label: {
                        HStack(spacing: 2) {
                            Text(showAllCast ? "Thu gọn" : "Xem tất cả")
                                .font(ThemeFont.display(size: 11, weight: .bold))
                            Image(systemName: showAllCast ? "chevron.up" : "chevron.right")
                                .font(ThemeFont.body(size: 9, weight: .bold))
                        }
                        .foregroundStyle(themeManager.colors.link)
                    }
                }
            }

            let visibleActors = showAllCast ? actors : Array(actors.prefix(6))
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) { // PERF-02: Use LazyHStack for deferred image loading
                    ForEach(visibleActors, id: \.id) { person in
                        castAvatar(person)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func castAvatar(_ person: CastMember) -> some View {
        let hasPerson = person.slug != nil && !(person.slug?.isEmpty ?? true)

        Group {
            if hasPerson, let slug = person.slug {
                NavigationLink(value: PersonDestination(slug: slug)) {
                    castAvatarContent(person, tappable: true)
                }
                .buttonStyle(.plain)
            } else {
                castAvatarContent(person, tappable: false)
            }
        }
    }

    @ViewBuilder
    private func castInitial(_ person: CastMember) -> some View {
        Text(person.initial)
            .font(ThemeFont.display(size: 14, weight: .bold))
            .foregroundStyle(ThemeColor.textMuted)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                LinearGradient(
                    colors: [themeManager.colors.link.opacity(0.3), themeManager.colors.brand.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }

    @ViewBuilder
    private func castAvatarContent(_ person: CastMember, tappable: Bool) -> some View {
        VStack(spacing: 4) {
            ZStack(alignment: .bottomTrailing) {
                // Use the project's caching image view instead of stock AsyncImage
                // so cast photos aren't refetched/redecoded on every appearance.
                CachedAsyncImage(url: person.photoUrl.flatMap { URL(string: $0) }) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    castInitial(person)
                } failure: {
                    castInitial(person)
                }
                .frame(width: 50, height: 50)
                .clipShape(Circle())

                if tappable {
                    Image(systemName: AppIcon.chevronRight)
                        .font(ThemeFont.body(size: 6, weight: .heavy))
                        .foregroundStyle(ThemeColor.textPrimary)
                        .padding(3)
                        .background(themeManager.colors.brand, in: Circle())
                        .offset(x: 2, y: 2)
                }
            }

            Text(person.name)
                .font(ThemeFont.body(size: 10, weight: .bold))
                .foregroundStyle(tappable ? themeManager.colors.link : .primary)
                .lineLimit(1)
                .frame(width: 60)

            if let character = person.characterName {
                Text(character)
                    .font(ThemeFont.body(size: 8))
                    .foregroundStyle(ThemeColor.textMuted)
                    .lineLimit(1)
                    .frame(width: 60)
            }
        }
    }

    // MARK: - Info Items Builder

    private struct InfoGridItem {
        let icon: String
        let label: String
        let value: String
    }

    private func buildInfoItems(_ content: Content) -> [InfoGridItem] {
        var items: [InfoGridItem] = []

        // Directors are handled separately in directorCell

        if let studios = content.studios, !studios.isEmpty {
            items.append(.init(icon: AppIcon.building2, label: "Studio", value: studios.prefix(2).map(\.name).joined(separator: ", ")))
        }
        if let regions = content.regions, !regions.isEmpty {
            items.append(.init(icon: AppIcon.globe, label: "Quốc gia", value: regions.map(\.name).joined(separator: ", ")))
        }
        if let network = content.network {
            items.append(.init(icon: AppIcon.tv, label: "Kênh phát", value: network))
        }
        if let epCount = content.episodeCount, epCount > 1 {
            items.append(.init(icon: AppIcon.film, label: "Tập phim", value: "\(epCount) tập"))
        }
        if !isSeries, let duration = content.durationMinutes, duration > 0 {
            items.append(.init(icon: AppIcon.clock, label: "Thời lượng", value: "\(duration) phút"))
        }
        if let status = content.status {
            let displayStatus = switch status {
            case "ongoing": "Đang chiếu"
            case "completed": "Hoàn tất"
            case "trailer": "Sắp chiếu"
            default: status
            }
            items.append(.init(icon: AppIcon.checkmarkSeal, label: "Trạng thái", value: displayStatus))
        }

        return items
    }

    // MARK: - Helpers

    private func formatCount(_ count: Int) -> String {
        if count >= 1_000_000 { return String(format: "%.1fM", Double(count) / 1_000_000) }
        if count >= 1_000 { return String(format: "%.1fK", Double(count) / 1_000) }
        return "\(count)"
    }
}
