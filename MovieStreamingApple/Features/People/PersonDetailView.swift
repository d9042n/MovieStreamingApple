//
//  PersonDetailView.swift
//  MovieStreamingApple
//
//  Person detail page — mobile-first responsive layout.
//  Profile photo centered on backdrop, name + badges below,
//  info grid (2 cols), then tabbed bio/filmography.
//
//  Refactored: extracted PersonBannerView, PersonFilmCard,
//  PersonSkeletonView, PersonErrorView into Components/.
//

import SwiftUI

struct PersonDetailView: View {
    let slug: String
    @State private var viewModel = PersonDetailViewModel()
    @Environment(\.themeManager) private var themeManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var hSizeClass

    var body: some View {
        Group {
            if viewModel.isLoading {
                PersonSkeletonView()
            } else if let error = viewModel.error {
                PersonErrorView(
                    message: error,
                    onRetry: { await viewModel.retry(slug: slug) },
                    onGoBack: { dismiss() }
                )
            } else if let person = viewModel.person {
                personContent(person)
            }
        }
        .id(slug) // Fix: reset view identity when slug changes (#10)
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
            await viewModel.loadPerson(slug: slug)
        }
    }

    // MARK: - Main Content

    @ViewBuilder
    private func personContent(_ person: PersonDetail) -> some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // Immersive Backdrop Banner (shared component)
                PersonBannerView(backdropURLs: viewModel.allBackdropURLs)

                // Content below banner (overlapping)
                VStack(spacing: DesignTokens.Spacing.xl) {
                    // Centered photo (overlapping banner)
                    photoView(person)
                        .frame(width: 130, height: 173)
                        .padding(.top, -60)

                    // Name + Badges
                    nameSection(person)

                    // Info card — stats, details, links
                    infoCard(person)

                    // Tab content (Biography / Filmography)
                    tabSection(person)
                }
                .padding(.horizontal, DesignTokens.Spacing.horizontalPadding(hSizeClass))
                .padding(.bottom, DesignTokens.Spacing.xxxl)
                .adaptiveContainer()
            }
        }
        .scrollIndicators(.hidden)
        .ignoresSafeArea(edges: .top)
        .navigationDestination(for: ContentDestination.self) { dest in
            ContentDetailView(slug: dest.slug, contentType: dest.type)
        }
    }

    // MARK: - Photo

    private func photoView(_ person: PersonDetail) -> some View {
        ZStack {
            if let photoUrl = person.photoUrl, let url = URL(string: photoUrl) {
                CachedAsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                } placeholder: {
                    AvatarPlaceholderView(name: person.name, fontSize: 40)
                }
            } else {
                AvatarPlaceholderView(name: person.name, fontSize: 40)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    person.isFeatured == true
                        ? themeManager.colors.highlight.opacity(0.5)
                        : ThemeColor.textPrimary.opacity(0.1),
                    lineWidth: person.isFeatured == true ? 2 : 1
                )
        )
        .shadow(color: .black.opacity(0.6), radius: 24, y: 12)
        .overlay(alignment: .top) {
            if person.isFeatured == true {
                HStack(spacing: 3) {
                    Image(systemName: AppIcon.starFill)
                        .font(ThemeFont.body(size: 8))
                    Text("Nổi bật")
                        .font(ThemeFont.body(size: 8, weight: .bold))
                        .textCase(.uppercase)
                        .tracking(0.5)
                }
                .foregroundStyle(ThemeColor.textPrimary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(themeManager.colors.highlight.opacity(0.9))
                .clipShape(Capsule())
                .offset(y: -10)
            }
        }
    }

    // MARK: - Name & Badges (centered)

    private func nameSection(_ person: PersonDetail) -> some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            Text(person.name)
                .font(ThemeFont.display(size: 26, weight: .bold))
                .foregroundStyle(ThemeColor.textPrimary)
                .multilineTextAlignment(.center)

            // Badges row
            HStack(spacing: 6) {
                if !viewModel.departmentLabel.isEmpty {
                    chipBadge(viewModel.departmentLabel, color: themeManager.colors.highlight)
                }
                if let gender = person.gender, gender != "unspecified" {
                    chipBadge(
                        gender == "male" ? "Nam" : gender == "female" ? "Nữ" : gender,
                        color: themeManager.colors.link
                    )
                }
                if let nationality = person.nationality {
                    chipBadge(nationality, color: .secondary)
                }
            }
        }
    }

    private func chipBadge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(ThemeFont.body(size: 11, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(color.opacity(0.2), lineWidth: 1))
    }

    // MARK: - Info Card

    private func infoCard(_ person: PersonDetail) -> some View {
        VStack(spacing: 0) {
            statsRow(person)
                .padding(.vertical, 14)

            cardDivider

            infoDetailsSection(person)

            externalLinksSection(person)
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(ThemeColor.textPrimary.opacity(0.08), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func statsRow(_ person: PersonDetail) -> some View {
        HStack(spacing: 0) {
            if viewModel.totalContents > 0 {
                statItem(
                    value: "\(viewModel.totalContents)",
                    label: "Tác phẩm",
                    icon: AppIcon.filmFill,
                    color: themeManager.colors.highlight
                )
            }
            if let age = viewModel.age {
                statItem(
                    value: "\(age)",
                    label: "Tuổi",
                    icon: AppIcon.personFill,
                    color: themeManager.colors.link
                )
            }
            if let filmography = person.filmography, !filmography.isEmpty {
                statItem(
                    value: "\(filmography.keys.count)",
                    label: "Lĩnh vực",
                    icon: AppIcon.rectangleStackFill,
                    color: themeManager.colors.brand
                )
            }
        }
    }

    @ViewBuilder
    private func infoDetailsSection(_ person: PersonDetail) -> some View {
        let items = buildInfoItems(person)
        if !items.isEmpty {
            VStack(spacing: 0) {
                ForEach(Array(stride(from: 0, to: items.count, by: 2)), id: \.self) { rowStart in
                    if rowStart > 0 {
                        Rectangle()
                            .fill(ThemeColor.textPrimary.opacity(0.04))
                            .frame(height: 1)
                    }
                    HStack(spacing: 0) {
                        infoCell(
                            icon: items[rowStart].icon,
                            iconColor: items[rowStart].color,
                            label: items[rowStart].label,
                            value: items[rowStart].value
                        )

                        Rectangle()
                            .fill(ThemeColor.textPrimary.opacity(0.04))
                            .frame(width: 1)

                        if rowStart + 1 < items.count {
                            infoCell(
                                icon: items[rowStart + 1].icon,
                                iconColor: items[rowStart + 1].color,
                                label: items[rowStart + 1].label,
                                value: items[rowStart + 1].value
                            )
                        } else {
                            Color.clear.frame(maxWidth: .infinity)
                        }
                    }
                }
            }

            cardDivider
        }
    }

    @ViewBuilder
    private func externalLinksSection(_ person: PersonDetail) -> some View {
        let links = viewModel.socialLinks
        if links.hasAny || person.tmdbId != nil {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    if let imdbId = links.imdbId {
                        externalLink(label: "IMDb", icon: AppIcon.link, urlString: "https://www.imdb.com/name/\(imdbId)")
                    }
                    if let tmdbId = person.tmdbId {
                        externalLink(label: "TMDB", icon: AppIcon.link, urlString: "https://www.themoviedb.org/person/\(tmdbId)")
                    }
                    if let twitterId = links.twitterId {
                        externalLink(label: "X", icon: AppIcon.at, urlString: "https://twitter.com/\(twitterId)")
                    }
                    if let instagramId = links.instagramId {
                        externalLink(label: "Instagram", icon: AppIcon.camera, urlString: "https://instagram.com/\(instagramId)")
                    }
                    if let facebookId = links.facebookId {
                        externalLink(label: "Facebook", icon: AppIcon.person2, urlString: "https://facebook.com/\(facebookId)")
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.md)
                .padding(.vertical, DesignTokens.Spacing.md)
            }
        }
    }

    private var cardDivider: some View {
        Rectangle()
            .fill(ThemeColor.textPrimary.opacity(0.06))
            .frame(height: 1)
    }

    private func statItem(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(ThemeFont.body(size: 14))
                .foregroundStyle(color)
            Text(value)
                .font(ThemeFont.display(size: 20, weight: .bold))
                .foregroundStyle(ThemeColor.textPrimary)
            Text(label)
                .font(ThemeFont.body(size: 10, weight: .medium))
                .foregroundStyle(ThemeColor.textMuted)
                .textCase(.uppercase)
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
    }

    private struct InfoItem {
        let icon: String
        let color: Color
        let label: String
        let value: String
    }

    private func buildInfoItems(_ person: PersonDetail) -> [InfoItem] {
        var items: [InfoItem] = []

        if let birthDate = viewModel.formattedBirthDate {
            let ageStr = viewModel.age.map { " (\($0))" } ?? ""
            items.append(InfoItem(icon: AppIcon.calendar, color: .secondary, label: "Ngày sinh", value: birthDate + ageStr))
        }
        if let birthPlace = person.birthPlace, !birthPlace.isEmpty {
            items.append(InfoItem(icon: AppIcon.mappinAndEllipse, color: .secondary, label: "Nơi sinh", value: birthPlace))
        }
        if let nationality = person.nationality, !nationality.isEmpty {
            items.append(InfoItem(icon: AppIcon.globe, color: .secondary, label: "Quốc tịch", value: nationality))
        }
        if !viewModel.departmentLabel.isEmpty {
            items.append(InfoItem(icon: AppIcon.filmFill, color: themeManager.colors.highlight, label: "Nghề nghiệp", value: viewModel.departmentLabel))
        }
        return items
    }

    private func infoCell(icon: String, iconColor: Color, label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(ThemeFont.body(size: 10))
                    .foregroundStyle(iconColor)
                Text(label.uppercased())
                    .font(ThemeFont.body(size: 10, weight: .bold))
                    .foregroundStyle(ThemeColor.textMuted)
                    .tracking(1)
            }
            Text(value)
                .font(ThemeFont.body(size: 12, weight: .medium))
                .foregroundStyle(ThemeColor.textPrimary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
    }

    /// Safe external link — no force-unwrap (#3)
    @ViewBuilder
    private func externalLink(label: String, icon: String, urlString: String) -> some View {
        if let url = URL(string: urlString) {
            Link(destination: url) {
                HStack(spacing: 4) {
                    Image(systemName: icon)
                        .font(ThemeFont.body(size: 10))
                    Text(label)
                        .font(ThemeFont.body(size: 11, weight: .bold))
                    Image(systemName: AppIcon.arrowUpRight)
                        .font(ThemeFont.body(size: 7))
                }
                .foregroundStyle(themeManager.colors.link)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(themeManager.colors.link.opacity(0.1))
                .clipShape(Capsule())
            }
        }
    }

    // MARK: - Tabs

    private func tabSection(_ person: PersonDetail) -> some View {
        VStack(spacing: 0) {
            // Tab bar
            HStack(spacing: 0) {
                ForEach(PersonTab.allCases) { tab in
                    Button {
                        withAnimation(DesignTokens.Animation.quick) {
                            viewModel.selectedTab = tab
                        }
                    } label: {
                        VStack(spacing: 6) {
                            Text(tab.label(totalContents: viewModel.totalContents))
                                .font(ThemeFont.body(size: 13, weight: viewModel.selectedTab == tab ? .bold : .semibold))
                                .foregroundStyle(viewModel.selectedTab == tab ? .primary : .secondary)

                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(viewModel.selectedTab == tab ? themeManager.colors.brand : .clear)
                                .frame(height: 3)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .padding(.top, DesignTokens.Spacing.lg)

            Divider()
                .background(ThemeColor.textPrimary.opacity(0.06))

            // Tab content — with transition animation (#27)
            Group {
                switch viewModel.selectedTab {
                case .biography:
                    biographyTab(person)
                case .filmography:
                    filmographyTab(person)
                }
            }
            .padding(DesignTokens.Spacing.lg)
            .animation(.easeInOut(duration: 0.25), value: viewModel.selectedTab)
            .transition(.opacity)
        }
        .background(ThemeColor.textPrimary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(ThemeColor.textPrimary.opacity(0.06), lineWidth: 1)
        )
    }

    // MARK: - Biography Tab

    private func biographyTab(_ person: PersonDetail) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            // Bio text
            if let bio = viewModel.displayedBio {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                    Text(bio)
                        .font(ThemeFont.body(size: 14))
                        .foregroundStyle(ThemeColor.textMuted)
                        .lineSpacing(5)

                    if viewModel.bioIsLong {
                        Button {
                            withAnimation { viewModel.bioExpanded.toggle() }
                        } label: {
                            HStack(spacing: 4) {
                                Text(viewModel.bioExpanded ? "Thu gọn" : "Đọc thêm")
                                    .font(ThemeFont.body(size: 13, weight: .bold))
                                Image(systemName: AppIcon.chevronDown)
                                    .font(ThemeFont.body(size: 10, weight: .bold))
                                    .rotationEffect(.degrees(viewModel.bioExpanded ? 180 : 0))
                            }
                            .foregroundStyle(themeManager.colors.link)
                        }
                    }
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: AppIcon.textPage)
                        .font(ThemeFont.display(size: 24))
                        .foregroundStyle(ThemeColor.textMuted.opacity(0.3))
                    Text("Thông tin tiểu sử chưa được cập nhật.")
                        .font(ThemeFont.body(size: 13))
                        .foregroundStyle(ThemeColor.textMuted)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            }

            // Also Known As
            if let aliases = person.alsoKnownAs, !aliases.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 5) {
                        Image(systemName: AppIcon.person2)
                            .font(ThemeFont.body(size: 10))
                            .foregroundStyle(themeManager.colors.link)
                        Text("TÊN KHÁC")
                            .font(ThemeFont.body(size: 9, weight: .bold))
                            .foregroundStyle(ThemeColor.textMuted)
                            .tracking(1.5)
                    }

                    FlowLayout(spacing: 6) {
                        ForEach(aliases, id: \.self) { alias in
                            Text(alias)
                                .font(ThemeFont.body(size: 11))
                                .foregroundStyle(ThemeColor.textMuted)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(ThemeColor.textPrimary.opacity(0.04))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(ThemeColor.textPrimary.opacity(0.06), lineWidth: 1)
                                )
                        }
                    }
                }
                .padding(14)
                .background(ThemeColor.textPrimary.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(ThemeColor.textPrimary.opacity(0.04), lineWidth: 1)
                )
            }
        }
    }

    // MARK: - Filmography Tab

    private func filmographyTab(_ person: PersonDetail) -> some View {
        let departments = Array(person.filmography?.keys ?? [:].keys)

        return VStack(alignment: .leading, spacing: 24) {
            if departments.isEmpty {
                VStack(spacing: DesignTokens.Spacing.lg) {
                    Image(systemName: AppIcon.film)
                        .font(ThemeFont.display(size: 36))
                        .foregroundStyle(ThemeColor.textMuted.opacity(0.3))
                    Text("Chưa có tác phẩm")
                        .font(ThemeFont.display(size: 16, weight: .bold))
                        .foregroundStyle(ThemeColor.textPrimary)
                    Text("Filmography sẽ được cập nhật sớm.")
                        .font(ThemeFont.body(size: 13))
                        .foregroundStyle(ThemeColor.textMuted)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                ForEach(departments.sorted(), id: \.self) { dept in
                    filmographySection(dept: dept)
                }
            }
        }
    }

    private func filmographySection(dept: String) -> some View {
        let items = viewModel.displayItems(for: dept)
        let totalCount = viewModel.sortedFilmography(for: dept).count
        let hasMore = viewModel.hasMoreItems(for: dept)
        let showAll = viewModel.filmShowAll[dept] ?? false

        let columns = DesignTokens.AdaptiveGrid.posterColumns(hSizeClass)

        return VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            // Section header
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(themeManager.colors.highlight)
                    .frame(width: 3, height: 18)

                Text(PersonDetailViewModel.getDepartmentLabel(dept).uppercased())
                    .font(ThemeFont.body(size: 13, weight: .bold))
                    .foregroundStyle(ThemeColor.textPrimary)
                    .tracking(0.5)

                Text("(\(totalCount))")
                    .font(ThemeFont.body(size: 12))
                    .foregroundStyle(ThemeColor.textMuted)
            }

            // Grid
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(items) { film in
                    PersonFilmCard(film: film)
                }
            }

            // Show all toggle
            if hasMore {
                Button {
                    withAnimation { viewModel.toggleShowAll(for: dept) }
                } label: {
                    HStack(spacing: 4) {
                        Text(showAll ? "Thu gọn" : "Xem tất cả \(totalCount) tác phẩm")
                            .font(ThemeFont.body(size: 12, weight: .bold))
                        Image(systemName: AppIcon.chevronDown)
                            .font(ThemeFont.body(size: 9, weight: .bold))
                            .rotationEffect(.degrees(showAll ? 180 : 0))
                    }
                    .foregroundStyle(themeManager.colors.link)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(ThemeColor.textPrimary.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Person Detail") {
    NavigationStack {
        PersonDetailView(slug: "tom-hanks")
    }
    .environment(\.themeManager, ThemeManager())
    .preferredColorScheme(.dark)
}
