//
//  BlogSectionView.swift
//  MovieStreamingApple
//
//  Blog posts section — equivalent to the website's "Latest News" section.
//

import SwiftUI

struct BlogSectionView: View {
    let blogPosts: [BlogPost]

    @Environment(\.themeManager) private var themeManager
    @State private var selectedPost: BlogPost?

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
                }

                Divider()
                    .overlay(themeManager.colors.border)

                // Blog posts grid — now tappable
                VStack(spacing: DesignTokens.Spacing.md) {
                    ForEach(Array(blogPosts.prefix(4))) { post in
                        Button {
                            selectedPost = post
                        } label: {
                            blogPostCard(post)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .sheet(item: $selectedPost) { post in
                BlogPostSheet(post: post)
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
        .accessibilityLabel(post.title)
        .accessibilityHint("Nhấn để đọc bài viết")
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Blog Post Detail Sheet

private struct BlogPostSheet: View {
    let post: BlogPost
    @Environment(\.dismiss) private var dismiss
    @Environment(\.themeManager) private var themeManager

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                    // Category badge
                    if let category = post.categoryName, !category.isEmpty {
                        Text(category)
                            .font(ThemeFont.display(size: 11, weight: .heavy))
                            .textCase(.uppercase)
                            .tracking(1)
                            .foregroundStyle(themeManager.colors.link)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(themeManager.colors.link.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }

                    // Title
                    Text(post.title)
                        .font(ThemeFont.display(size: 22, weight: .bold))
                        .foregroundStyle(themeManager.colors.textPrimary)

                    // Meta
                    HStack(spacing: DesignTokens.Spacing.md) {
                        if let author = post.authorName, !author.isEmpty {
                            Label(author, systemImage: "person.circle")
                                .font(ThemeFont.body(size: 12))
                                .foregroundStyle(themeManager.colors.textBody)
                        }
                        if let date = post.formattedDate {
                            Label(date, systemImage: "calendar")
                                .font(ThemeFont.body(size: 12))
                                .foregroundStyle(themeManager.colors.textMuted)
                        }
                    }

                    Divider()
                        .overlay(themeManager.colors.border)

                    // Content
                    if let content = post.content, !content.isEmpty {
                        Text(content.strippingHTML)
                            .font(ThemeFont.body(size: 15))
                            .foregroundStyle(themeManager.colors.textBody)
                            .lineSpacing(6)
                    } else if let excerpt = post.excerpt, !excerpt.isEmpty {
                        Text(excerpt.strippingHTML)
                            .font(ThemeFont.body(size: 15))
                            .foregroundStyle(themeManager.colors.textBody)
                            .lineSpacing(6)
                    } else {
                        Text("Nội dung đang được cập nhật...")
                            .font(ThemeFont.body(size: 14))
                            .foregroundStyle(themeManager.colors.textMuted)
                            .italic()
                    }
                }
                .padding(DesignTokens.Spacing.lg)
            }
            .navigationTitle("Tin Mới")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Đóng") { dismiss() }
                        .font(ThemeFont.body(size: 17, weight: .semibold))
                }
            }
        }
    }
}
