//
//  DetailTabSectionView.swift
//  MovieStreamingApple
//
//  Tab section with segmented control for Overview, Episodes, Cast, Reviews.
//  Mirrors the website's TabSection component.
//

import SwiftUI

struct DetailTabSectionView: View {
    @Bindable var viewModel: ContentDetailViewModel
    @Environment(\.themeManager) private var themeManager

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Tab Selector
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    ForEach(viewModel.availableTabs) { tab in
                        tabButton(tab)
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.xs)
            }
            .padding(.vertical, DesignTokens.Spacing.md)

            // MARK: - Tab Content — with transition animation (#26)
            VStack(spacing: 0) {
                switch viewModel.activeTab {
                case .overview:
                    DetailOverviewView(viewModel: viewModel)
                case .episodes:
                    DetailEpisodesView(viewModel: viewModel)
                case .cast:
                    DetailCastView(viewModel: viewModel)
                case .reviews:
                    DetailReviewsView()
                }
            }
            .padding(.top, DesignTokens.Spacing.lg)
            .animation(.easeInOut(duration: 0.25), value: viewModel.activeTab)
            .transition(.opacity)
        }
        .padding(DesignTokens.Spacing.lg)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(ThemeColor.textPrimary.opacity(0.06), lineWidth: 1)
        )
    }

    // MARK: - Tab Button

    @ViewBuilder
    private func tabButton(_ tab: DetailTab) -> some View {
        let isActive = viewModel.activeTab == tab

        Button {
            withAnimation(DesignTokens.Animation.quick) {
                viewModel.activeTab = tab
            }
        } label: {
            VStack(spacing: 6) {
                Text(tabLabel(for: tab))
                    .font(ThemeFont.body(size: 13, weight: isActive ? .bold : .medium))
                    .foregroundStyle(isActive ? .white : .secondary)
                    .padding(.horizontal, DesignTokens.Spacing.md)
                    .padding(.vertical, DesignTokens.Spacing.sm)

                Rectangle()
                    .fill(isActive ? themeManager.colors.brand : .clear)
                    .frame(height: 2)
            }
        }
    }

    private func tabLabel(for tab: DetailTab) -> String {
        switch tab {
        case .overview: return "Tổng Quan"
        case .episodes:
            if let count = viewModel.content?.episodeCount, count > 0 {
                return "Tập Phim (\(count))"
            }
            return "Tập Phim"
        case .cast:
            let count = viewModel.allCast.count
            return count > 0 ? "Diễn Viên (\(count))" : "Diễn Viên"
        case .reviews: return "Đánh Giá"
        }
    }
}
