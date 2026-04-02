//
//  PeopleView.swift
//  MovieStreamingApple
//
//  People directory — search and browse actors/artists.
//  Mirrors the website's PeopleDirectory.tsx with grid layout,
//  search bar, sort, gender filter, and cursor-based pagination.
//

import SwiftUI

struct PeopleView: View {
    @State private var viewModel = PeopleViewModel()
    @Environment(\.themeManager) private var themeManager
    @Environment(\.horizontalSizeClass) private var hSizeClass

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    // Invisible scroll anchor
                    Color.clear
                        .frame(height: 0)
                        .id("people-top")

                    // MARK: - Header
                    headerSection

                    // MARK: - Toolbar
                    toolbarSection
                        .padding(.horizontal, DesignTokens.Spacing.horizontalPadding(hSizeClass))
                        .padding(.top, DesignTokens.Spacing.lg)

                    // MARK: - Active Filters
                    if viewModel.hasActiveFilters && !viewModel.isLoading {
                        activeFiltersBar
                            .padding(.horizontal, DesignTokens.Spacing.horizontalPadding(hSizeClass))
                            .padding(.top, DesignTokens.Spacing.md)
                    }

                    // MARK: - Content
                    contentSection
                        .padding(.horizontal, DesignTokens.Spacing.horizontalPadding(hSizeClass))
                        .padding(.top, DesignTokens.Spacing.lg)
                        .padding(.bottom, 32)
                        .adaptiveContainer()
                }
            }
            .onChange(of: viewModel.scrollToTopTrigger) { _, _ in
                withAnimation(DesignTokens.Animation.standard) {
                    proxy.scrollTo("people-top", anchor: .top)
                }
            }
        }
        .background(ThemeColor.bgBase.ignoresSafeArea())
        .navigationTitle("Nghệ Sĩ")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: PersonDestination.self) { dest in
            PersonDetailView(slug: dest.slug)
        }
        .task {
            if viewModel.people.isEmpty {
                await viewModel.loadPeople()
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: AppIcon.person2Fill)
                .font(ThemeFont.display(size: 32))
                .foregroundStyle(
                    LinearGradient(
                        colors: [themeManager.colors.brand, themeManager.colors.highlight],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text("Nghệ Sĩ")
                .font(ThemeFont.display(size: 24, weight: .bold))
                .foregroundStyle(ThemeColor.textPrimary)
        }
        .padding(.vertical, DesignTokens.Spacing.xxl)
    }

    // MARK: - Toolbar

    private var toolbarSection: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            // Row 1: Search + Sort
            HStack(spacing: DesignTokens.Spacing.md) {
                // Search field
                HStack(spacing: 8) {
                    Image(systemName: AppIcon.magnifyingglass)
                        .font(ThemeFont.body(size: 14))
                        .foregroundStyle(ThemeColor.textMuted)

                    TextField("Tìm nghệ sĩ...", text: $viewModel.searchText)
                        .font(ThemeFont.body(size: 14))
                        .foregroundStyle(ThemeColor.textPrimary)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    if !viewModel.searchText.isEmpty {
                        Button {
                            viewModel.searchText = "" // onChange will trigger onSearchChanged
                        } label: {
                            Image(systemName: AppIcon.xmarkCircleFill)
                                .font(ThemeFont.body(size: 14))
                                .foregroundStyle(ThemeColor.textMuted)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(ThemeColor.textPrimary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(ThemeColor.textPrimary.opacity(0.08), lineWidth: 1)
                )
                .onChange(of: viewModel.searchText) { _, newValue in
                    viewModel.onSearchChanged(newValue)
                }

                // Sort Menu
                Menu {
                    ForEach(PeopleSortOption.allCases) { option in
                        Button {
                            viewModel.selectedSort = option
                            Task { await viewModel.onFilterChanged() }
                        } label: {
                            HStack {
                                Text(option.label)
                                if viewModel.selectedSort == option {
                                    Image(systemName: AppIcon.checkmark)
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: AppIcon.arrowUpArrowDown)
                            .font(ThemeFont.body(size: 12, weight: .medium))
                        Text(viewModel.selectedSort.label)
                            .font(ThemeFont.body(size: 11, weight: .bold))
                            .lineLimit(1)
                    }
                    .foregroundStyle(ThemeColor.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(ThemeColor.textPrimary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(ThemeColor.textPrimary.opacity(0.08), lineWidth: 1)
                    )
                }
            }

            // Row 2: Gender filter chips
            HStack(spacing: 4) {
                ForEach(GenderFilter.allCases) { filter in
                    Button {
                        viewModel.selectedGender = filter
                        Task { await viewModel.onFilterChanged() }
                    } label: {
                        Text(filter.label)
                            .font(ThemeFont.body(size: 11, weight: .bold))
                            .textCase(.uppercase)
                            .tracking(0.5)
                            .foregroundStyle(viewModel.selectedGender == filter ? .white : .secondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                viewModel.selectedGender == filter
                                    ? themeManager.colors.brand
                                    : ThemeColor.textPrimary.opacity(0.06)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                Spacer()
            }
            .padding(4)
            .background(ThemeColor.textPrimary.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(ThemeColor.textPrimary.opacity(0.06), lineWidth: 1)
            )
        }
    }

    // MARK: - Active Filters Bar

    private var activeFiltersBar: some View {
        HStack {
            Text("Đang lọc: \(viewModel.totalCount ?? viewModel.people.count) kết quả")
                .font(ThemeFont.body(size: 12))
                .foregroundStyle(ThemeColor.textMuted)

            Spacer()

            Button {
                Task { await viewModel.clearFilters() }
            } label: {
                Text("Xóa bộ lọc")
                    .font(ThemeFont.body(size: 12, weight: .bold))
                    .foregroundStyle(themeManager.colors.brand)
            }
        }
    }

    // MARK: - Content Section

    @ViewBuilder
    private var contentSection: some View {
        if viewModel.isLoading {
            skeletonGrid
        } else if let error = viewModel.error {
            errorState(error)
        } else if viewModel.people.isEmpty {
            emptyState
        } else {
            VStack(spacing: DesignTokens.Spacing.lg) {
                // People grid
                peopleGrid

                // Load more button
                if viewModel.hasMore {
                    loadMoreButton
                }
            }
        }
    }

    // MARK: - People Grid

    private var peopleGrid: some View {
        let columns = DesignTokens.AdaptiveGrid.peopleColumns(hSizeClass)

        return LazyVGrid(columns: columns, spacing: 14) {
            ForEach(viewModel.people) { person in
                NavigationLink(value: PersonDestination(slug: person.slug)) {
                    personCard(person)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func personCard(_ person: PersonListItem) -> some View {
        VStack(spacing: 6) {
            // Photo — Color.clear container enforces 3:4 ratio
            Color.clear
                .aspectRatio(3 / 4, contentMode: .fit)
                .overlay(alignment: .top) {
                    if let photoUrl = person.photoUrl, let url = URL(string: photoUrl) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                            case .failure:
                                AvatarPlaceholderView(name: person.name)
                            default:
                                AvatarPlaceholderView(name: person.name)
                                    .shimmer()
                            }
                        }
                    } else {
                        AvatarPlaceholderView(name: person.name)
                    }
                }
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(ThemeColor.textPrimary.opacity(0.06), lineWidth: 1)
                )

            // Name
            Text(person.name)
                .font(ThemeFont.body(size: 12, weight: .bold))
                .foregroundStyle(ThemeColor.textPrimary)
                .lineLimit(1)

            // Known-for badges
            if let knownFor = person.knownFor, !knownFor.isEmpty {
                HStack(spacing: 3) {
                    ForEach(Array(knownFor.prefix(3))) { item in
                        Text(item.title)
                            .font(ThemeFont.body(size: 8, weight: .medium))
                            .foregroundStyle(ThemeColor.textMuted)
                            .lineLimit(1)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(ThemeColor.textPrimary.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
            }

            // Content count
            if let count = person.contentCount, count > 0 {
                Text("\(count) phim")
                    .font(ThemeFont.body(size: 10))
                    .foregroundStyle(ThemeColor.textMuted)
            }
        }
    }

    // initialAvatar replaced by shared AvatarPlaceholderView

    // MARK: - Load More

    private var loadMoreButton: some View {
        Button {
            Task { await viewModel.loadMore() }
        } label: {
            HStack(spacing: 8) {
                if viewModel.isLoadingMore {
                    ProgressView()
                        .controlSize(.small)
                    Text("Đang tải...")
                } else {
                    Text("Xem thêm (\(viewModel.people.count)\(viewModel.totalCount.map { "/\($0)" } ?? "+"))")
                }
            }
            .font(ThemeFont.body(size: 13, weight: .bold))
            .textCase(.uppercase)
            .tracking(1)
            .foregroundStyle(ThemeColor.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(ThemeColor.textPrimary.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(ThemeColor.textPrimary.opacity(0.08), lineWidth: 1)
            )
        }
        .disabled(viewModel.isLoadingMore)
    }

    // MARK: - Skeleton

    private var skeletonGrid: some View {
        let columns = DesignTokens.AdaptiveGrid.peopleColumns(hSizeClass)
        let skeletonCount = hSizeClass == .regular ? 18 : 12

        return LazyVGrid(columns: columns, spacing: 14) {
            ForEach(0..<skeletonCount, id: \.self) { _ in
                VStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(ThemeColor.textPrimary.opacity(0.06))
                        .aspectRatio(3 / 4, contentMode: .fit)
                        .overlay { ProgressView().controlSize(.small) }

                    RoundedRectangle(cornerRadius: 4)
                        .fill(ThemeColor.textPrimary.opacity(0.06))
                        .frame(height: 12)
                        .frame(maxWidth: 80)
                }
            }
        }
    }

    // MARK: - Error State

    private func errorState(_ message: String) -> some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Image(systemName: AppIcon.exclamationmarkTriangleFill)
                .font(ThemeFont.display(size: 36))
                .foregroundStyle(themeManager.colors.highlight)

            Text("Lỗi tải dữ liệu")
                .font(ThemeFont.display(size: 16, weight: .bold))
                .foregroundStyle(ThemeColor.textPrimary)

            Text(message)
                .font(ThemeFont.body(size: 13))
                .foregroundStyle(ThemeColor.textMuted)
                .multilineTextAlignment(.center)

            Button {
                Task { await viewModel.retry() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: AppIcon.arrowClockwise)
                        .font(ThemeFont.body(size: 12, weight: .bold))
                    Text("Thử lại")
                        .font(ThemeFont.body(size: 14, weight: .bold))
                }
                .foregroundStyle(ThemeColor.textPrimary)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(themeManager.colors.brand, in: Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Image(systemName: AppIcon.person2)
                .font(ThemeFont.display(size: 40))
                .foregroundStyle(ThemeColor.textMuted.opacity(0.3))

            Text(viewModel.hasActiveFilters ? "Không tìm thấy kết quả" : "Chưa có nghệ sĩ")
                .font(ThemeFont.display(size: 16, weight: .bold))
                .foregroundStyle(ThemeColor.textPrimary)

            Text(viewModel.hasActiveFilters
                 ? "Thử thay đổi bộ lọc hoặc từ khóa tìm kiếm."
                 : "Danh sách nghệ sĩ đang được cập nhật.")
                .font(ThemeFont.body(size: 13))
                .foregroundStyle(ThemeColor.textMuted)
                .multilineTextAlignment(.center)

            if viewModel.hasActiveFilters {
                Button {
                    Task { await viewModel.clearFilters() }
                } label: {
                    Text("Xóa bộ lọc")
                        .font(ThemeFont.body(size: 14, weight: .bold))
                        .foregroundStyle(themeManager.colors.brand)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }
}

// MARK: - Preview

#Preview("People") {
    NavigationStack {
        PeopleView()
    }
    .environment(\.themeManager, ThemeManager())
    .preferredColorScheme(.dark)
}
