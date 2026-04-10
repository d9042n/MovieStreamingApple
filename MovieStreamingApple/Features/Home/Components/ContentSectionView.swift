//
//  ContentSectionView.swift
//  MovieStreamingApple
//
//  A content section with tab filtering — Netflix/Disney+ horizontal carousel style.
//  Used for both "Movies" and "TV Series" sections on HomeView.
//
//  Layout: Header + Tab Picker → Horizontal scroll rail of poster cards
//  Same visual language as CollectionRailView but with interactive tab filtering.
//

import SwiftUI

struct ContentSectionView: View {
    let title: String
    let tabs: [ContentTab]
    @Binding var activeTab: ContentTab
    let contents: [Content]
    let isLoading: Bool

    @Environment(\.themeManager) private var themeManager
    @Environment(\.horizontalSizeClass) private var hSizeClass

    /// Adaptive card width: slightly larger on iPad
    private var cardWidth: CGFloat {
        hSizeClass == .regular ? 160 : DesignTokens.PosterSize.railWidth
    }

    /// Horizontal edge padding
    private var hPadding: CGFloat {
        DesignTokens.Spacing.horizontalPadding(hSizeClass)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            // MARK: - Section Header
            sectionHeader
                .padding(.horizontal, hPadding)

            // MARK: - Tab Picker
            tabPicker
                .padding(.horizontal, hPadding)

            // MARK: - Content Rail
            contentArea
        }
    }

    // MARK: - Section Header

    private var sectionHeader: some View {
        HStack(alignment: .center) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(themeManager.colors.brand)
                    .frame(width: 3, height: 22)

                Text(title)
                    .font(ThemeFont.display(size: 20, weight: .bold))
                    .foregroundStyle(themeManager.colors.textPrimary)
                    .textCase(.uppercase)
            }

            Spacer()

            if !contents.isEmpty {
                Text("Top \(contents.count)")
                    .font(ThemeFont.body(size: 11))
                    .foregroundStyle(themeManager.colors.textMuted)
                    .textCase(.uppercase)
            }
        }
    }

    // MARK: - Tab Picker

    private var tabPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                ForEach(tabs) { tab in
                    TabButton(
                        tab: tab,
                        isActive: activeTab == tab,
                        action: {
                            withAnimation(DesignTokens.Animation.quick) {
                                activeTab = tab
                            }
                        }
                    )
                }
            }
        }
    }

    // MARK: - Content Area

    @ViewBuilder
    private var contentArea: some View {
        if isLoading {
            railShimmer
        } else if contents.isEmpty {
            emptyState
                .padding(.horizontal, hPadding)
        } else {
            contentRail
        }
    }

    // MARK: - Horizontal Rail (Netflix-style)

    private var contentRail: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: DesignTokens.Spacing.md) {
                    ForEach(contents) { item in
                        NavigationLink(value: item) {
                            ContentCardView(content: item)
                                .frame(width: cardWidth)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, hPadding)
                // Invisible anchor for scroll reset
                .background(alignment: .leading) {
                    Color.clear.frame(width: 1).id("rail-start")
                }
            }
            // Reset scroll position on tab change without destroying view tree
            .onChange(of: activeTab) { _, _ in
                withAnimation(DesignTokens.Animation.quick) {
                    proxy.scrollTo("rail-start", anchor: .leading)
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: AppIcon.film)
                .font(ThemeFont.display(size: 22))
                .foregroundStyle(themeManager.colors.textMuted)
            Text("Chưa có nội dung trong mục này.")
                .font(ThemeFont.body(size: 13))
                .foregroundStyle(themeManager.colors.textBody)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignTokens.Spacing.xxxl)
        .background(themeManager.colors.bgCardAlt.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.large))
    }

    // MARK: - Rail Shimmer (matches CollectionRailView shimmer)

    private var railShimmer: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignTokens.Spacing.md) {
                ForEach(0..<8, id: \.self) { _ in
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                        RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.poster)
                            .fill(themeManager.colors.bgCardAlt)
                            .frame(width: cardWidth, height: cardWidth * 1.5)
                            .shimmer()
                        RoundedRectangle(cornerRadius: 4)
                            .fill(themeManager.colors.bgCardAlt)
                            .frame(width: cardWidth, height: 12)
                            .shimmer()
                        RoundedRectangle(cornerRadius: 4)
                            .fill(themeManager.colors.bgCardAlt)
                            .frame(width: cardWidth * 0.6, height: 10)
                            .shimmer()
                    }
                }
            }
            .padding(.horizontal, hPadding)
        }
    }
}

// MARK: - Tab Button

private struct TabButton: View {
    let tab: ContentTab
    let isActive: Bool
    let action: () -> Void

    @Environment(\.themeManager) private var themeManager

    var body: some View {
        Button(action: action) {
            Text(tab.label)
                .font(ThemeFont.display(size: 13, weight: isActive ? .bold : .medium))
                .foregroundStyle(isActive ? themeManager.colors.textPrimary : themeManager.colors.textBody)
                .padding(.horizontal, DesignTokens.Spacing.md)
                .padding(.vertical, DesignTokens.Spacing.sm)
                .background(tabBackground)
                .clipShape(Capsule())
                .overlay(tabBorder)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var tabBackground: some View {
        if isActive {
            Rectangle().fill(themeManager.colors.brand.opacity(0.15))
        } else {
            Color.clear
        }
    }

    @ViewBuilder
    private var tabBorder: some View {
        if isActive {
            Capsule()
                .strokeBorder(themeManager.colors.brand.opacity(0.3), lineWidth: 1)
        } else {
            Capsule()
                .strokeBorder(Color.clear, lineWidth: 1)
        }
    }
}
