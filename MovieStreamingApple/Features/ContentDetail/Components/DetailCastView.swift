//
//  DetailCastView.swift
//  MovieStreamingApple
//
//  Cast tab: grid of cast member cards with photos or initial avatars.
//  Mirrors the website's Cast tab in ContentDetail.tsx.
//

import SwiftUI

struct DetailCastView: View {
    @Bindable var viewModel: ContentDetailViewModel

    @Environment(\.themeManager) private var themeManager

    var body: some View {
        if viewModel.allCast.isEmpty {
            emptyState
        } else {
            VStack(spacing: DesignTokens.Spacing.lg) {
                // Cast grid
                let columns = [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12),
                ]

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(viewModel.displayedCast, id: \.id) { actor in
                        castCard(actor)
                    }
                }

                // Show more/less button
                if viewModel.allCast.count > 10 {
                    Button {
                        withAnimation(DesignTokens.Animation.standard) {
                            viewModel.showAllCast.toggle()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(viewModel.showAllCast
                                ? "Thu gọn"
                                : "Xem tất cả \(viewModel.allCast.count) diễn viên")
                                .font(ThemeFont.body(size: 13, weight: .bold))
                                .foregroundStyle(themeManager.colors.link)

                            Image(systemName: AppIcon.chevronRight)
                                .font(ThemeFont.body(size: 12, weight: .medium))
                                .foregroundStyle(themeManager.colors.link)
                                .rotationEffect(.degrees(viewModel.showAllCast ? 90 : 0))
                        }
                    }
                    .padding(.top, DesignTokens.Spacing.sm)
                }
            }
        }
    }

    // MARK: - Cast Card

    @ViewBuilder
    private func castCard(_ actor: CastMember) -> some View {
        if let slug = actor.slug, !slug.isEmpty {
            // Safe unwrap — no force-unwrap (#4)
            NavigationLink(
                value: PersonDestination(slug: slug)
            ) {
                castCardContent(actor, isTappable: true)
            }
            .buttonStyle(.plain)
        } else {
            castCardContent(actor, isTappable: false)
        }
    }

    @ViewBuilder
    private func castCardContent(_ actor: CastMember, isTappable: Bool) -> some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            // Photo or initial avatar
            ZStack(alignment: .bottomTrailing) {
                if let photoUrl = actor.photoUrl,
                   let url = URL(string: photoUrl) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        initialAvatar(actor.initial)
                    }
                    .frame(width: 64, height: 64)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(ThemeColor.textPrimary.opacity(0.08), lineWidth: 2)
                    )
                } else {
                    initialAvatar(actor.initial)
                }

                // Navigation indicator for tappable cards
                if isTappable {
                    Image(systemName: AppIcon.chevronRightCircleFill)
                        .font(ThemeFont.body(size: 14))
                        .foregroundStyle(ThemeColor.textPrimary)
                        .background(ThemeColor.bgBase.opacity(0.4), in: Circle())
                }
            }

            // Name
            Text(actor.name)
                .font(ThemeFont.body(size: 12, weight: .bold))
                .foregroundStyle(ThemeColor.textPrimary)
                .lineLimit(1)
                .multilineTextAlignment(.center)

            // Character name
            if let character = actor.characterName, !character.isEmpty {
                Text(character)
                    .font(ThemeFont.body(size: 10, weight: .light))
                    .foregroundStyle(ThemeColor.textMuted)
                    .lineLimit(1)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignTokens.Spacing.md)
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .background(ThemeColor.textPrimary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(ThemeColor.textPrimary.opacity(0.06), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(actor.name)\(actor.characterName.map { ", vai \($0)" } ?? "")")
        .accessibilityAddTraits(isTappable ? .isButton : [])
    }

    // Initial avatar placeholder
    private func initialAvatar(_ initial: String) -> some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [themeManager.colors.link.opacity(0.6), themeManager.colors.brand.opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 64, height: 64)
            .overlay {
                Text(initial)
                    .font(ThemeFont.display(size: 22, weight: .bold))
                    .foregroundStyle(ThemeColor.textPrimary)
            }
    }

    // Empty state
    private var emptyState: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Image(systemName: AppIcon.person2)
                .font(ThemeFont.display(size: 36))
                .foregroundStyle(ThemeColor.textMuted)
            Text("Chưa có thông tin diễn viên.")
                .font(ThemeFont.body(size: 14))
                .foregroundStyle(ThemeColor.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .background(ThemeColor.textPrimary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [6]))
                .foregroundStyle(ThemeColor.textPrimary.opacity(0.08))
        )
    }
}
