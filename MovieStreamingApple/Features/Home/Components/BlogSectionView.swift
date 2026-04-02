//
//  BlogSectionView.swift
//  MovieStreamingApple
//
//  Blog posts section — equivalent to the website's "Tin Mới" section.
//

import SwiftUI

struct BlogSectionView: View {
    let blogPosts: [BlogPost]

    @Environment(\.themeManager) private var themeManager

    var body: some View {
        if !blogPosts.isEmpty {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                // Header
                HStack {
                    HStack(spacing: DesignTokens.Spacing.sm) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(themeManager.colors.link)
                            .frame(width: 3, height: 22)
                        Text("Tin Mới")
                            .font(ThemeFont.display(size: 20, weight: .bold))
                            .foregroundStyle(themeManager.colors.textPrimary)
                            .textCase(.uppercase)
                    }

                    Spacer()

                    // TODO: Enable when blog list view is implemented
                    // NavigationLink("Xem tất cả", value: "blog")
                    //     .font(ThemeFont.body(size: 12))
                    //     .foregroundStyle(themeManager.colors.textMuted)
                }

                Divider()
                    .overlay(themeManager.colors.border)

                // Blog posts grid
                VStack(spacing: DesignTokens.Spacing.md) {
                    ForEach(Array(blogPosts.prefix(4))) { post in
                        blogPostCard(post)
                    }
                }
            }
        }
    }

    private func blogPostCard(_ post: BlogPost) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            if let category = post.categoryName, !category.isEmpty {
                Text(category)
                    .font(ThemeFont.display(size: 10, weight: .heavy))
                    .textCase(.uppercase)
                    .tracking(1)
                    .foregroundStyle(themeManager.colors.link)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(themeManager.colors.link.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            Text(post.title)
                .font(ThemeFont.display(size: 15, weight: .bold))
                .foregroundStyle(themeManager.colors.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            if let date = post.formattedDate {
                Text(date)
                    .font(ThemeFont.body(size: 11))
                    .foregroundStyle(themeManager.colors.textMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignTokens.Spacing.lg)
        .background(themeManager.colors.bgCardAlt.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.card))
    }
}
