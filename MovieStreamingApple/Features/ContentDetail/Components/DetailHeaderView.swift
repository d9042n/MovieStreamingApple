//
//  DetailHeaderView.swift
//  MovieStreamingApple
//
//  Title, original title, actions bar (favorite, share, rating),
//  streaming meta badges, and stats badges.
//  Mirrors the website's right column header section.
//

import SwiftUI

struct DetailHeaderView: View {
    let content: Content
    let viewModel: ContentDetailViewModel

    @Environment(\.themeManager) private var themeManager

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            // MARK: - Title + Year
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(content.title)
                        .font(ThemeFont.display(size: 26, weight: .bold))
                        .foregroundStyle(ThemeColor.textPrimary)

                    if let year = viewModel.releaseYear {
                        Text("(\(String(year)))")
                            .font(ThemeFont.display(size: 18, weight: .light))
                            .foregroundStyle(ThemeColor.textMuted)
                    }
                }

                if let originalTitle = content.originalTitle,
                   originalTitle != content.title {
                    Text(originalTitle)
                        .font(ThemeFont.body(size: 16, weight: .light))
                        .foregroundStyle(ThemeColor.textMuted.opacity(0.6))
                        .tracking(0.3)
                }
            }

            // MARK: - Actions & Rating Bar
            VStack(spacing: DesignTokens.Spacing.md) {
                // Actions row — centered
                HStack(spacing: DesignTokens.Spacing.lg) {
                    // Yêu thích — disabled with accessibility (#13)
                    disabledActionButton(icon: AppIcon.heart, label: "Yêu thích")
                    divider
                    // Chia sẻ — functional
                    shareButton
                }
                .frame(maxWidth: .infinity)

                Divider()
                    .overlay(ThemeColor.textPrimary.opacity(0.08))

                // Rating row — centered
                HStack(spacing: DesignTokens.Spacing.xl) {
                    // Average rating
                    VStack(spacing: 4) {
                        ratingStars(score: content.averageRating ?? 0)
                        Text(viewModel.ratingCount > 0
                            ? "\(viewModel.ratingCount.formatted()) đánh giá"
                            : "Chưa có đánh giá")
                            .font(ThemeFont.body(size: 11, weight: .light))
                            .foregroundStyle(ThemeColor.textMuted)
                    }

                    divider

                    // User rating — disabled (no backend yet)
                    VStack(spacing: 4) {
                        Text("Đánh giá phim:")
                            .font(ThemeFont.body(size: 11, weight: .light))
                            .foregroundStyle(ThemeColor.textMuted)
                        HStack(spacing: 2) {
                            ForEach(1...5, id: \.self) { _ in
                                Image(systemName: AppIcon.star)
                                    .font(ThemeFont.body(size: 14))
                                    .foregroundStyle(ThemeColor.textMuted)
                            }
                        }
                        .opacity(0.5)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(DesignTokens.Spacing.md)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(ThemeColor.textPrimary.opacity(0.06), lineWidth: 1)
            )

            // MARK: - Streaming Meta & Stats Badges
            metaBadgesFlow
        }
    }

    // MARK: - Sub-views

    /// Disabled action button for features without backend data yet.
    @ViewBuilder
    private func disabledActionButton(icon: String, label: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(ThemeFont.body(size: 14))
                .foregroundStyle(.tertiary)
            Text(label)
                .font(ThemeFont.body(size: 13, weight: .bold))
                .foregroundStyle(.tertiary)
        }
        .opacity(0.5)
    }

    /// Share button — uses SwiftUI ShareLink (no UIKit coupling #5).
    private var shareButton: some View {
        let typePrefix = content.type == .series ? "tv" : "movie"
        let shareURL = URL(string: "https://d9042n.online/detail/\(typePrefix)/\(content.slug ?? content.id)") ?? URL(string: "https://d9042n.online")!

        return ShareLink(
            item: shareURL,
            subject: Text(content.title),
            message: Text("Xem \(content.title) trên MovieStreaming")
        ) {
            HStack(spacing: 6) {
                Image(systemName: AppIcon.squareAndArrowUp)
                    .font(ThemeFont.body(size: 14))
                    .foregroundStyle(ThemeColor.textMuted)
                Text("Chia sẻ")
                    .font(ThemeFont.body(size: 13, weight: .bold))
                    .foregroundStyle(ThemeColor.textPrimary)
            }
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(ThemeColor.textPrimary.opacity(0.1))
            .frame(width: 1, height: 16)
    }

    @ViewBuilder
    private func ratingStars(score: Double) -> some View {
        HStack(spacing: 2) {
            let fullStars = Int(score / 2)
            let hasHalf = (score / 2) - Double(fullStars) >= 0.5

            ForEach(0..<5, id: \.self) { index in
                Image(systemName: index < fullStars ? AppIcon.starFill :
                        (index == fullStars && hasHalf ? AppIcon.starLeadingHalfFilled : AppIcon.star))
                    .font(ThemeFont.body(size: 12))
                    .foregroundStyle(themeManager.colors.highlight)
            }

            Text(String(format: "%.1f", score))
                .font(ThemeFont.body(size: 13, weight: .bold))
                .foregroundStyle(themeManager.colors.highlight)
                .padding(.leading, 4)
        }
    }

    // MARK: - Meta Badges Flow

    @ViewBuilder
    private var metaBadgesFlow: some View {
        let badges = buildBadges()
        if !badges.isEmpty {
            FlowLayout(spacing: 8) {
                ForEach(badges) { badge in
                    badge.view
                }
            }
        }
    }

    private func buildBadges() -> [BadgeItem] {
        var items: [BadgeItem] = []

        // Streaming meta
        if let quality = content.streamingMeta?.quality, !quality.isEmpty {
            items.append(BadgeItem(id: "quality") {
                AnyView(metaBadge(text: quality, style: .mono))
            })
        }
        if let language = content.streamingMeta?.language, !language.isEmpty {
            items.append(BadgeItem(id: "language") {
                AnyView(metaBadge(text: language, style: .mono))
            })
        }
        if let episodeCurrent = content.streamingMeta?.episodeCurrent, !episodeCurrent.isEmpty {
            items.append(BadgeItem(id: "episode") {
                AnyView(metaBadge(text: episodeCurrent, style: .highlight))
            })
        }
        if let contentRating = content.contentRating, !contentRating.isEmpty {
            items.append(BadgeItem(id: "rating") {
                AnyView(metaBadge(text: contentRating, style: .amber))
            })
        }

        // Stats
        if viewModel.totalViews > 0 {
            items.append(BadgeItem(id: "views") {
                AnyView(iconBadge(icon: AppIcon.eye, text: "\(viewModel.totalViews.formatted()) lượt xem"))
            })
        }
        if viewModel.dailyViews > 0 {
            items.append(BadgeItem(id: "daily") {
                AnyView(iconBadge(icon: AppIcon.eye, text: "+\(viewModel.dailyViews) hôm nay", tint: themeManager.colors.highlight))
            })
        }
        if viewModel.bookmarkCount > 0 {
            items.append(BadgeItem(id: "bookmarks") {
                AnyView(iconBadge(icon: AppIcon.bookmark, text: "\(viewModel.bookmarkCount) theo dõi"))
            })
        }
        if let minutes = content.durationMinutes, viewModel.isMovie {
            items.append(BadgeItem(id: "duration") {
                AnyView(iconBadge(icon: AppIcon.clock, text: "\(minutes) phút"))
            })
        }
        if let episodes = content.episodeCount, episodes > 1 {
            items.append(BadgeItem(id: "epCount") {
                AnyView(iconBadge(icon: AppIcon.film, text: "\(episodes) tập"))
            })
        }
        if let seasonCount = content.seasonCount, seasonCount > 0, viewModel.isSeries {
            items.append(BadgeItem(id: "seasons") {
                AnyView(iconBadge(icon: AppIcon.playCircle, text: "\(seasonCount) mùa"))
            })
        }
        if viewModel.isSeries {
            items.append(BadgeItem(id: "seriesTag") {
                AnyView(metaBadge(text: "Series", style: .highlight))
            })
        }

        return items
    }

    // MARK: - Badge Views

    private enum BadgeStyle { case mono, highlight, amber }

    @ViewBuilder
    private func metaBadge(text: String, style: BadgeStyle) -> some View {
        Text(text)
            .font(ThemeFont.display(size: 11, weight: .bold).monospaced())
            .foregroundStyle(badgeForeground(style))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(badgeBackground(style))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(badgeBorder(style), lineWidth: 1)
            )
    }

    @ViewBuilder
    private func iconBadge(icon: String, text: String, tint: Color = .secondary) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(ThemeFont.body(size: 11))
            Text(text)
                .font(ThemeFont.body(size: 11))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(ThemeColor.textPrimary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(ThemeColor.textPrimary.opacity(0.06), lineWidth: 1)
        )
    }

    private func badgeForeground(_ style: BadgeStyle) -> Color {
        switch style {
        case .mono: return .primary
        case .highlight: return themeManager.colors.link
        case .amber: return themeManager.colors.highlight
        }
    }

    private func badgeBackground(_ style: BadgeStyle) -> Color {
        switch style {
        case .mono: return ThemeColor.textPrimary.opacity(0.08)
        case .highlight: return themeManager.colors.link.opacity(0.1)
        case .amber: return themeManager.colors.highlight.opacity(0.1)
        }
    }

    private func badgeBorder(_ style: BadgeStyle) -> Color {
        switch style {
        case .mono: return ThemeColor.textPrimary.opacity(0.1)
        case .highlight: return themeManager.colors.link.opacity(0.2)
        case .amber: return themeManager.colors.highlight.opacity(0.2)
        }
    }
}

// MARK: - Badge Item

private struct BadgeItem: Identifiable {
    let id: String
    let view: AnyView

    init(id: String, @ViewBuilder content: () -> AnyView) {
        self.id = id
        self.view = content()
    }
}

// MARK: - Flow Layout (simple wrapping layout)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: ProposedViewSize(result.sizes[index])
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> ArrangeResult {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var sizes: [CGSize] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            sizes.append(size)
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        let totalHeight = y + rowHeight
        return ArrangeResult(
            size: CGSize(width: maxWidth, height: totalHeight),
            positions: positions,
            sizes: sizes
        )
    }

    private struct ArrangeResult {
        let size: CGSize
        let positions: [CGPoint]
        let sizes: [CGSize]
    }
}
