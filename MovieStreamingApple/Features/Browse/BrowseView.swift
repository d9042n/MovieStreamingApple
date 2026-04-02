//
//  BrowseView.swift
//  MovieStreamingApple
//
//  Content directory / Browse page — mirrors the website's ContentDirectory.tsx.
//  Shows a searchable, filterable, sortable grid of all content with cursor pagination.
//

import SwiftUI

struct BrowseView: View {
    @Environment(AppRouter.self) private var router
    @State private var viewModel = BrowseViewModel()
    @State private var isFilterSheetPresented = false

    @Environment(\.themeManager) private var themeManager
    @Environment(\.horizontalSizeClass) private var hSizeClass

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Fixed Header (outside scroll to avoid NavigationLink conflicts)
            browseHeader

            // MARK: - Scrollable Content
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        // Invisible scroll anchor
                        Color.clear
                            .frame(height: 0)
                            .id("browse-top")

                        // Top Bar (count + sort)
                        topBar
                            .padding(.horizontal, DesignTokens.Spacing.horizontalPadding(hSizeClass))
                            .padding(.top, DesignTokens.Spacing.md)

                        // Content Area
                        contentArea
                            .padding(.horizontal, DesignTokens.Spacing.horizontalPadding(hSizeClass))
                            .padding(.top, DesignTokens.Spacing.lg)
                            .padding(.bottom, DesignTokens.Spacing.xxxl)
                            .adaptiveContainer()
                    }
                }
                .scrollIndicators(.hidden)
                .onChange(of: viewModel.scrollToTopTrigger) { _, _ in
                    withAnimation(DesignTokens.Animation.standard) {
                        proxy.scrollTo("browse-top", anchor: .top)
                    }
                }
            }
        }
        .background(themeManager.colors.bgBase)
        .navigationTitle("Khám phá")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: Content.self) { content in
            ContentDetailView(
                slug: content.slug ?? content.id,
                contentType: content.type ?? .movie
            )
        }
        .sheet(isPresented: $isFilterSheetPresented) {
            BrowseFilterSheet(viewModel: viewModel)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isFilterSheetPresented = true
                } label: {
                    Image(systemName: AppIcon.line3HorizontalDecreaseCircle)
                        .foregroundStyle(viewModel.hasActiveFilters ? themeManager.colors.brand : themeManager.colors.textMuted)
                        .overlay(alignment: .topTrailing) {
                            if viewModel.activeFilterCount > 0 {
                                Text("\(viewModel.activeFilterCount)")
                                    .font(ThemeFont.body(size: 10, weight: .bold))
                                    .foregroundStyle(ThemeColor.textPrimary)
                                    .minimumScaleFactor(0.8)
                                    .frame(width: 16, height: 16)
                                    .background(themeManager.colors.brand, in: Circle())
                                    .offset(x: 4, y: -4)
                            }
                        }
                }
                .accessibilityLabel("Bộ lọc")
                .accessibilityHint("Mở bộ lọc nội dung")
                .accessibilityValue(viewModel.activeFilterCount > 0 ? "\(viewModel.activeFilterCount) bộ lọc đang áp dụng" : "Không có bộ lọc")
            }
        }
        .searchable(text: $viewModel.searchText, prompt: "Tìm phim, diễn viên...")
        .onChange(of: viewModel.searchText) { _, _ in
            viewModel.searchChanged()
        }
        .onChange(of: router.browseTargetGenreSlug) { _, newSlug in
            if let slug = newSlug, router.selectedTab == .search {
                applyGenreFromRouter(slug)
                // Consume the target so it doesn't re-trigger
                router.browseTargetGenreSlug = nil
            }
        }
        .task {
            // Apply initial genre filter if present on first load
            if let slug = router.browseTargetGenreSlug {
                viewModel.selectedGenreSlugs.insert(slug)
                router.browseTargetGenreSlug = nil
            }
            async let taxonomies: () = viewModel.loadTaxonomies()
            async let contents: () = viewModel.fetchContents()
            _ = await (taxonomies, contents)
        }
        .refreshable {
            await viewModel.fetchContents()
        }
    }
    
    private func applyGenreFromRouter(_ slug: String) {
        viewModel.selectedGenreSlugs.removeAll()
        viewModel.selectedGenreSlugs.insert(slug)
        viewModel.selectedType = .all
        viewModel.selectedStatus = .all
        viewModel.selectedRegionSlugs.removeAll()
        viewModel.sortOption = .updatedAtDesc
        
        Task {
            await viewModel.fetchContents()
        }
    }

    // MARK: - Browse Header

    private var browseHeader: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            // Quick Type Filters — evenly distributed
            HStack(spacing: DesignTokens.Spacing.sm) {
                ForEach(BrowseTypeFilter.allCases) { typeFilter in
                    Button {
                        viewModel.setType(typeFilter)
                    } label: {
                        Label(typeFilter.label, systemImage: typeFilter.icon)
                            .font(ThemeFont.body(size: 13, weight: viewModel.selectedType == typeFilter ? .bold : .medium))
                            .foregroundStyle(viewModel.selectedType == typeFilter ? .white : themeManager.colors.textMuted)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DesignTokens.Spacing.sm)
                            .background(
                                viewModel.selectedType == typeFilter
                                    ? AnyShapeStyle(themeManager.colors.brand)
                                    : AnyShapeStyle(.ultraThinMaterial)
                            )
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.lockedType != nil)
                    .accessibilityLabel(typeFilter.label)
                    .accessibilityAddTraits(viewModel.selectedType == typeFilter ? .isSelected : [])
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.lg)

            // Quick Status Filters — evenly distributed
            HStack(spacing: DesignTokens.Spacing.xs) {
                ForEach(BrowseStatusFilter.allCases) { statusFilter in
                    Button {
                        viewModel.setStatus(statusFilter)
                    } label: {
                        Text(statusFilter.label)
                            .font(ThemeFont.body(size: 12, weight: viewModel.selectedStatus == statusFilter ? .semibold : .regular))
                            .foregroundStyle(viewModel.selectedStatus == statusFilter ? themeManager.colors.textPrimary : themeManager.colors.textMuted)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(
                                viewModel.selectedStatus == statusFilter
                                    ? themeManager.colors.overlaySubtle
                                    : Color.clear
                            )
                            .clipShape(Capsule())
                            .overlay {
                                Capsule()
                                    .strokeBorder(
                                        viewModel.selectedStatus == statusFilter
                                            ? themeManager.colors.border.opacity(0.3)
                                            : Color.clear,
                                        lineWidth: 1
                                    )
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(statusFilter.label)
                    .accessibilityAddTraits(viewModel.selectedStatus == statusFilter ? .isSelected : [])
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.lg)
        }
        .padding(.vertical, DesignTokens.Spacing.md)
    }

    // MARK: - Top Bar (Count + Sort)

    private var topBar: some View {
        HStack {
            // Result count
            Group {
                if viewModel.isLoading {
                    Text("Đang tìm kiếm...")
                        .foregroundStyle(themeManager.colors.textMuted)
                } else {
                    HStack(spacing: 4) {
                        Text("Tìm thấy")
                            .foregroundStyle(themeManager.colors.textMuted)
                        Text("\(viewModel.totalCount)")
                            .foregroundStyle(themeManager.colors.textPrimary)
                            .fontWeight(.bold)
                        Text("nội dung")
                            .foregroundStyle(themeManager.colors.textMuted)
                    }
                }
            }
            .font(ThemeFont.body(size: 12))

            Spacer()

            // Sort picker
            Menu {
                ForEach(BrowseSortOption.allCases) { option in
                    Button {
                        viewModel.setSort(option)
                    } label: {
                        HStack {
                            Text(option.label)
                            if viewModel.sortOption == option {
                                Image(systemName: AppIcon.checkmark)
                            }
                        }
                    }
                }
            } label: {
                Label(viewModel.sortOption.label, systemImage: "arrow.up.arrow.down")
                    .font(ThemeFont.body(size: 12))
                    .foregroundStyle(themeManager.colors.textMuted)
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.large))
    }

    // MARK: - Content Area

    @ViewBuilder
    private var contentArea: some View {
        if let errorMsg = viewModel.error, !viewModel.isLoading {
            errorState(errorMsg)
        } else if viewModel.isLoading {
            skeletonGrid
        } else if viewModel.contents.isEmpty {
            emptyState
        } else {
            contentGrid
        }
    }

    // MARK: - Content Grid

    private var contentGrid: some View {
        let columns = DesignTokens.AdaptiveGrid.browseColumns(hSizeClass)
        let paginationTriggerID = viewModel.contents.suffix(4).first?.id

        return VStack(spacing: DesignTokens.Spacing.xl) {
            LazyVGrid(columns: columns, spacing: DesignTokens.Spacing.xl) {
                ForEach(viewModel.contents) { content in
                    NavigationLink(value: content) {
                        ContentCardView(content: content)
                    }
                    .buttonStyle(.plain)
                    .task {
                        if content.id == paginationTriggerID {
                            await viewModel.loadMore()
                        }
                    }
                }
            }

            if viewModel.hasMore {
                loadMoreButton
            }
        }
    }

    // MARK: - Load More Button

    private var loadMoreButton: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Divider()
                .overlay(themeManager.colors.overlaySubtle)

            Button {
                Task { await viewModel.loadMore() }
            } label: {
                HStack(spacing: DesignTokens.Spacing.sm) {
                    if viewModel.isLoadingMore {
                        ProgressView()
                            .tint(themeManager.colors.textPrimary)
                        Text("Đang tải...")
                    } else {
                        Text("Xem thêm")
                    }
                }
                .font(ThemeFont.display(size: 14, weight: .bold))
                .textCase(.uppercase)
                .tracking(1)
                .foregroundStyle(themeManager.colors.textPrimary)
                .padding(.horizontal, DesignTokens.Spacing.xxl)
                .padding(.vertical, DesignTokens.Spacing.md)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .overlay {
                    Capsule()
                        .strokeBorder(.quaternary, lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isLoadingMore)
            .accessibilityLabel("Xem thêm nội dung")
            .accessibilityHint("Tải thêm kết quả tìm kiếm")
        }
        .padding(.top, DesignTokens.Spacing.lg)
    }

    // MARK: - Skeleton

    private var skeletonGrid: some View {
        let columns = DesignTokens.AdaptiveGrid.browseColumns(hSizeClass)
        let skeletonCount = hSizeClass == .regular ? 12 : 8

        return LazyVGrid(columns: columns, spacing: DesignTokens.Spacing.xl) {
            ForEach(0..<skeletonCount, id: \.self) { _ in
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.poster)
                        .fill(.quaternary)
                        .aspectRatio(2 / 3, contentMode: .fit)
                        .shimmer()
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.quaternary)
                        .frame(height: 14)
                        .shimmer()
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.quaternary)
                        .frame(width: 80, height: 10)
                        .shimmer()
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Không tìm thấy nội dung", systemImage: "film.stack")
        } description: {
            Text("Không tìm thấy nội dung phù hợp với bộ lọc. Hãy thử thay đổi tiêu chí tìm kiếm.")
        } actions: {
            if viewModel.hasActiveFilters {
                Button("Xoá bộ lọc") {
                    viewModel.clearFilters()
                }
                .buttonStyle(.borderedProminent)
                .tint(themeManager.colors.brand)
            }
        }
        .padding(.vertical, DesignTokens.Spacing.xxxl)
    }

    // MARK: - Error State

    private func errorState(_ message: String) -> some View {
        ContentUnavailableView {
            Label("Lỗi tải dữ liệu", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("Thử lại") {
                Task { await viewModel.fetchContents() }
            }
            .buttonStyle(.borderedProminent)
            .tint(themeManager.colors.brand)
        }
        .padding(.vertical, DesignTokens.Spacing.xxxl)
    }
}

// MARK: - Preview

#Preview("Browse") {
    NavigationStack {
        BrowseView()
    }
    .environment(AppRouter())
    .preferredColorScheme(.dark)
}
