//
//  ContentDetailView.swift
//  MovieStreamingApple
//
//  Main content detail screen — adaptive for iPhone and iPad.
//
//  ┌───────────────────────────────────────────────────────────────────────┐
//  │ Compact (iPhone)  → Vertical stack: Banner → Poster → Header → Tabs │
//  │ Regular (iPad)    → Wider content with max-width constraint,         │
//  │                     more horizontal padding, centered layout         │
//  └───────────────────────────────────────────────────────────────────────┘
//

import SwiftUI

struct ContentDetailView: View {
    let slug: String
    let contentType: ContentType

    @State private var viewModel = ContentDetailViewModel()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var hSizeClass

    var body: some View {
        Group {
            if viewModel.isLoading {
                DetailSkeletonView()
            } else if let error = viewModel.error, viewModel.content == nil {
                DetailErrorView(errorMessage: error) {
                    await viewModel.loadContent(slug: slug, type: contentType)
                }
            } else if let content = viewModel.content {
                detailContent(content)
            }
        }
        .id(slug) // Fix: reset view identity when slug changes (#9)
        .background(ThemeColor.bgBase)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: AppIcon.chevronLeft)
                        .font(ThemeFont.body(size: 16, weight: .semibold))
                        .foregroundStyle(ThemeColor.textPrimary)
                        .padding(8)
                        .background(.ultraThinMaterial, in: Circle())
                }
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .task(id: slug) {
            await viewModel.loadContent(slug: slug, type: contentType)
        }
    }

    // MARK: - Main Detail Content

    @ViewBuilder
    private func detailContent(_ content: Content) -> some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // MARK: - Immersive Backdrop Banner
                DetailBannerView(
                    backdropUrl: content.backdropUrl,
                    posterUrl: content.posterUrl,
                    backdrops: viewModel.backdrops
                )

                // MARK: - Detail Body (adaptive padding + max width)
                VStack(spacing: DesignTokens.Spacing.xl) {
                    // Poster Card
                    DetailPosterView(
                        content: content,
                        statusInfo: viewModel.statusInfo
                    )

                    // Title, Ratings, Meta Badges
                    DetailHeaderView(
                        content: content,
                        viewModel: viewModel
                    )

                    // Tab Section
                    DetailTabSectionView(viewModel: viewModel)

                    // Related Content
                    if !viewModel.relatedContents.isEmpty {
                        DetailRelatedView(
                            contents: viewModel.relatedContents
                        )
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.horizontalPadding(hSizeClass))
                .padding(.top, -60) // Overlap with banner
                .padding(.bottom, DesignTokens.Spacing.xxxl)
                .adaptiveContainer()
            }
        }
        .scrollIndicators(.hidden)
        .ignoresSafeArea(edges: .top)
        .navigationDestination(for: Content.self) { relatedContent in
            ContentDetailView(
                slug: relatedContent.slug ?? relatedContent.id,
                contentType: relatedContent.type ?? .movie
            )
        }
        .navigationDestination(for: PersonDestination.self) { dest in
            PersonDetailView(slug: dest.slug)
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
    }
}

// MARK: - Preview

#Preview("Content Detail - Movie") {
    NavigationStack {
        ContentDetailView(
            slug: "spider-man-across-the-spider-verse",
            contentType: .movie
        )
    }
    .preferredColorScheme(.dark)
}

#Preview("Content Detail - Series") {
    NavigationStack {
        ContentDetailView(
            slug: "nhung-nguoi-ban-phan-10",
            contentType: .series
        )
    }
    .preferredColorScheme(.dark)
}
