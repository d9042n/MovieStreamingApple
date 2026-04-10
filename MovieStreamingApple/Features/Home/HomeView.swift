//
//  HomeView.swift
//  MovieStreamingApple
//
//  Main home screen — adaptive layout for iPhone and iPad.
//
//  ┌───────────────────────────────────────────────────────────────────────┐
//  │ Compact (iPhone)  → Full-width vertical scroll, existing layout      │
//  │ Regular (iPad)    → Centered content with max width constraint       │
//  │                     Wide (≥ landscape): 2/3 main + 1/3 sidebar       │
//  │                     Narrow (portrait): full-width, no sidebar         │
//  └───────────────────────────────────────────────────────────────────────┘
//

import SwiftUI

struct HomeView: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @State private var viewModel = HomeViewModel()

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                LazyVStack(spacing: 0) {
                    // MARK: - Hero Slider (always full-width, adapts internally)
                    HeroSliderView(contents: viewModel.heroContents)

                    // MARK: - Genre Carousel
                    GenreCarouselView(
                        genres: viewModel.visibleGenres,
                        isLoading: viewModel.isLoading
                    ) { genre in
                        router.navigateToBrowse(genreSlug: genre.slug)
                    }
                    .padding(.vertical, DesignTokens.Spacing.lg)

                    // MARK: - Main Content (adaptive layout)
                    mainContent(containerWidth: geo.size.width)
                        .padding(.bottom, DesignTokens.Spacing.xxxl)
                }
            }
            .scrollIndicators(.hidden)
            .ignoresSafeArea(edges: .top)
        }
        .navigationDestination(for: Content.self) { content in
            ContentDetailView(
                slug: content.effectiveSlug,
                contentType: content.type ?? .movie
            )
        }
        .task {
            await viewModel.fetchAll()
        }
        .refreshable {
            await viewModel.fetchAll()
        }
        .overlay {
            if let error = viewModel.error, !viewModel.isLoading {
                errorOverlay(error)
            }
        }
    }

    // MARK: - Adaptive Main Content

    @ViewBuilder
    private func mainContent(containerWidth: CGFloat) -> some View {
        // iPad and iPhone both use a straightforward stacked vertical layout
        // without the sidebar or platform stats overlay
        VStack(spacing: DesignTokens.Spacing.sectionSpacing(hSizeClass)) {
            mainSections
        }
        .frame(maxWidth: .infinity)
        .adaptiveContainer()
    }

    // MARK: - Main Sections (shared between layouts)

    @ViewBuilder
    private var mainSections: some View {
        // Section 1: Movies — horizontal rail
        ContentSectionView(
            title: "Phim Lẻ",
            tabs: ContentTab.allCases,
            activeTab: $viewModel.activeMovieTab,
            contents: viewModel.currentMovies,
            isLoading: viewModel.isLoading
        )

        // Section 2: TV Series — horizontal rail
        ContentSectionView(
            title: "Phim Bộ",
            tabs: ContentTab.allCases,
            activeTab: $viewModel.activeSeriesTab,
            contents: viewModel.currentSeries,
            isLoading: viewModel.isLoading
        )

        // Blog Posts
        BlogSectionView(blogPosts: viewModel.blogPosts)
            .padding(.horizontal, DesignTokens.Spacing.horizontalPadding(hSizeClass))

        // Curated Collection Rails (already handle own padding)
        CollectionRailsView(
            collections: viewModel.collections,
            isLoading: viewModel.isLoading
        )
    }

    // MARK: - Error Overlay

    private func errorOverlay(_ message: String) -> some View {
        ContentUnavailableView {
            Label("Lỗi kết nối", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("Thử lại") {
                Task { await viewModel.fetchAll() }
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

// MARK: - Preview

#Preview("Home Screen") {
    NavigationStack {
        HomeView()
    }
    .environment(AppRouter())
    .preferredColorScheme(.dark)
}
