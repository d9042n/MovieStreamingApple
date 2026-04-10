//
//  WatchingHubView.swift
//  MovieStreamingApple
//
//  "Continue Watching" hub — center tab root view.
//  Layout: Hero Slider (in-progress) → "Continue Watching" carousel → "Recently Viewed" carousel.
//  Empty state shows discovery prompt.
//
//  Data flow: WatchHistoryManager loads minimal entries from UserDefaults,
//  then fetches rich content (title, poster) from API via fetchContentDetails().
//

import SwiftUI

struct WatchingHubView: View {
    @Environment(WatchHistoryManager.self) private var historyManager
    @Environment(AppRouter.self) private var router
    @Environment(\.themeManager) private var themeManager
    @Environment(\.horizontalSizeClass) private var hSizeClass

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                switch historyManager.loadingState {
                case .idle, .loading:
                    loadingState

                case .loaded:
                    if historyManager.isEmpty {
                        emptyState
                    } else {
                        loadedContent
                    }

                case .error(let message):
                    errorState(message)
                }
            }
        }
        .scrollIndicators(.hidden)
        .ignoresSafeArea(edges: .top)
        .background(ThemeColor.bgBase)
        .task {
            await historyManager.fetchContentDetails()
        }
        // Navigation destinations — same pattern as HomeView
        .navigationDestination(for: Content.self) { content in
            ContentDetailView(
                slug: {
                    if let slug = content.slug, !slug.isEmpty { return slug }
                    return content.id
                }(),
                contentType: content.type ?? .movie
            )
        }
        .navigationDestination(for: ContentDestination.self) { dest in
            ContentDetailView(
                slug: dest.slug,
                contentType: dest.type
            )
        }
        .navigationDestination(for: PlayerDestination.self) { dest in
            PlayerPageView(
                slug: dest.slug,
                contentType: dest.type,
                episodeId: dest.episodeId,
                seasonNumber: dest.seasonNumber,
                episodeNumber: dest.episodeNumber,
                autoResume: dest.autoResume
            )
        }
        .navigationDestination(for: PersonDestination.self) { dest in
            PersonDetailView(slug: dest.slug)
        }
    }

    // MARK: - Loaded Content

    private var loadedContent: some View {
        Group {
            // MARK: Hero Slider (all watch history items)
            if !historyManager.allDisplayData.isEmpty {
                WatchingHeroSliderView(
                    items: historyManager.allDisplayData,
                    onContinue: { item in navigateToWatch(displayData: item) },
                    onDetail: { item in navigateToDetail(displayData: item) }
                )
            }

            // MARK: Continue Watching Carousel
            if !historyManager.continueWatching.isEmpty {
                sectionCarousel(
                    title: "Đang Xem",
                    items: historyManager.continueWatching
                )
            }

            // MARK: Recently Viewed Carousel
            if !historyManager.recentlyViewed.isEmpty {
                sectionCarousel(
                    title: "Xem Gần Đây",
                    items: historyManager.recentlyViewed
                )
            }
        }
    }

    // MARK: - Section Carousel

    private func sectionCarousel(
        title: String,
        items: [WatchDisplayData]
    ) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            // Section Header
            HStack(spacing: DesignTokens.Spacing.sm) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(themeManager.colors.brand)
                    .frame(width: 3, height: 22)

                Image(systemName: AppIcon.sparkles)
                    .font(ThemeFont.body(size: 12))
                    .foregroundStyle(themeManager.colors.highlight.opacity(0.7))

                Text(title)
                    .font(ThemeFont.display(size: 17, weight: .bold))
                    .foregroundStyle(themeManager.colors.textPrimary)
                    .textCase(.uppercase)

                Spacer()

                if !items.isEmpty {
                    Text("\(items.count) Phim")
                        .font(ThemeFont.body(size: 11))
                        .foregroundStyle(themeManager.colors.textMuted)
                        .textCase(.uppercase)
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.horizontalPadding(hSizeClass))

            // Horizontal scroll
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: DesignTokens.Spacing.md) {
                    ForEach(items) { item in
                        Button {
                            navigateToDetail(displayData: item)
                        } label: {
                            WatchingCardView(displayData: item)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                withAnimation(DesignTokens.Animation.standard) {
                                    historyManager.remove(entryId: item.entry.id)
                                }
                            } label: {
                                Label("Xoá khỏi lịch sử", systemImage: AppIcon.trash)
                            }

                            Button {
                                navigateToWatch(displayData: item)
                            } label: {
                                Label(
                                    item.entry.isFinished ? "Xem lại" : "Xem tiếp",
                                    systemImage: AppIcon.playFill
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.horizontalPadding(hSizeClass))
            }
        }
        .padding(.top, DesignTokens.Spacing.xxl)
    }

    // MARK: - Loading State

    private var loadingState: some View {
        VStack(spacing: 0) {
            // Hero shimmer
            Rectangle()
                .fill(ThemeColor.bgCard)
                .frame(height: 420)
                .overlay {
                    ProgressView()
                        .tint(themeManager.colors.brand)
                        .scaleEffect(1.2)
                }

            // Cards shimmer
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(ThemeColor.bgCard)
                    .frame(width: 140, height: 20)
                    .padding(.horizontal, DesignTokens.Spacing.lg)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DesignTokens.Spacing.md) {
                        ForEach(0..<3, id: \.self) { _ in
                            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.poster)
                                    .fill(ThemeColor.bgCard)
                                    .aspectRatio(2 / 3, contentMode: .fit)
                                    .frame(width: DesignTokens.PosterSize.railWidth)

                                RoundedRectangle(cornerRadius: 4)
                                    .fill(ThemeColor.bgCard)
                                    .frame(width: 100, height: 14)
                            }
                        }
                    }
                    .padding(.horizontal, DesignTokens.Spacing.lg)
                }
            }
            .padding(.top, DesignTokens.Spacing.xxl)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: DesignTokens.Spacing.xxl) {
            Spacer()
                .frame(height: 120)

            Image(systemName: AppIcon.playCircle)
                .font(ThemeFont.display(size: 64, weight: .thin))
                .foregroundStyle(themeManager.colors.textMuted.opacity(0.5))

            VStack(spacing: DesignTokens.Spacing.sm) {
                Text("Chưa có nội dung")
                    .font(ThemeFont.display(size: 22, weight: .bold))
                    .foregroundStyle(themeManager.colors.textPrimary)

                Text("Bắt đầu xem phim để theo dõi tiến trình tại đây")
                    .font(ThemeFont.body(size: 15))
                    .foregroundStyle(themeManager.colors.textMuted)
                    .multilineTextAlignment(.center)
            }

            Button {
                router.selectedTab = .search
            } label: {
                HStack(spacing: DesignTokens.Spacing.sm) {
                    Image(systemName: AppIcon.sparkles)
                    Text("Khám phá ngay")
                        .font(ThemeFont.display(size: 15, weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, DesignTokens.Spacing.xxl)
                .padding(.vertical, DesignTokens.Spacing.md)
                .background(themeManager.colors.brand)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.medium))
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, DesignTokens.Spacing.xxl)
    }

    // MARK: - Error State

    private func errorState(_ message: String) -> some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Spacer()
                .frame(height: 120)

            Image(systemName: AppIcon.exclamationmarkTriangle)
                .font(ThemeFont.display(size: 48, weight: .thin))
                .foregroundStyle(themeManager.colors.textMuted)

            Text("Không thể tải dữ liệu")
                .font(ThemeFont.display(size: 18, weight: .bold))
                .foregroundStyle(themeManager.colors.textPrimary)

            Text(message)
                .font(ThemeFont.body(size: 13))
                .foregroundStyle(themeManager.colors.textMuted)

            Button {
                Task { await historyManager.fetchContentDetails() }
            } label: {
                HStack(spacing: DesignTokens.Spacing.sm) {
                    Image(systemName: AppIcon.arrowClockwise)
                    Text("Thử lại")
                        .font(ThemeFont.display(size: 15, weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, DesignTokens.Spacing.xxl)
                .padding(.vertical, DesignTokens.Spacing.md)
                .background(themeManager.colors.brand)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.medium))
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Navigation Helpers

    private func navigateToWatch(displayData: WatchDisplayData) {
        let dest = PlayerDestination(
            slug: displayData.entry.slug,
            type: displayData.entry.contentType,
            episodeId: displayData.entry.currentEpisodeId,
            seasonNumber: displayData.entry.seasonNumber,
            episodeNumber: displayData.entry.episodeNumber,
            autoResume: true
        )
        router.watchingPath.append(dest)
    }

    private func navigateToDetail(displayData: WatchDisplayData) {
        // P1-03: Use lightweight ContentDestination instead of
        // constructing a full Content object with 25+ nil fields
        let dest = ContentDestination(
            slug: displayData.entry.slug,
            type: displayData.entry.contentType
        )
        router.watchingPath.append(dest)
    }
}

// MARK: - Preview

#Preview("Watching Hub") {
    NavigationStack {
        WatchingHubView()
    }
    .environment(WatchHistoryManager())
    .environment(AppRouter())
    .environment(\.themeManager, ThemeManager())
    .preferredColorScheme(.dark)
}
