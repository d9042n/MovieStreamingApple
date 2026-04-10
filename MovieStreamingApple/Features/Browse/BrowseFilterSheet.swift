//
//  BrowseFilterSheet.swift
//  MovieStreamingApple
//
//  Filter sheet for Browse page — mirrors website's FilterSidebar.tsx.
//  Displayed as a bottom sheet with genre, region, type, and status multi-select.
//
//  UX: Genre/Region sections show top 6 items collapsed + selected items pinned.
//  Expanding reveals full searchable list in a clean grouped layout.
//

import SwiftUI

struct BrowseFilterSheet: View {
    var viewModel: BrowseViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.themeManager) private var themeManager

    @State private var isGenreExpanded = false
    @State private var isRegionExpanded = false
    @State private var genreSearch = ""
    @State private var regionSearch = ""

    // MARK: - Constants

    private let maxCollapsedItems = 6

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxl) {
                    // MARK: - Active Filters
                    if viewModel.hasActiveFilters {
                        activeFiltersSection
                    }

                    // MARK: - Genre
                    filterSection(title: "Thể Loại", icon: "film") {
                        collapsibleMultiSelect(
                            items: viewModel.genres.map { TagItem(slug: $0.slug, name: $0.name, count: $0.contentCount) },
                            selected: viewModel.selectedGenreSlugs,
                            isExpanded: $isGenreExpanded,
                            searchText: $genreSearch,
                            isLoading: viewModel.isLoadingTaxonomies,
                            onToggle: { viewModel.toggleGenre($0) }
                        )
                    }

                    // MARK: - Region
                    filterSection(title: "Quốc Gia", icon: "globe") {
                        collapsibleMultiSelect(
                            items: viewModel.regions.map { TagItem(slug: $0.slug, name: $0.name, count: $0.contentCount) },
                            selected: viewModel.selectedRegionSlugs,
                            isExpanded: $isRegionExpanded,
                            searchText: $regionSearch,
                            isLoading: viewModel.isLoadingTaxonomies,
                            onToggle: { viewModel.toggleRegion($0) }
                        )
                    }

                    // MARK: - Type (hidden when locked)
                    if viewModel.lockedType == nil {
                        filterSection(title: "Định Dạng", icon: "square.stack") {
                            typeSelection
                        }
                    }

                    // MARK: - Status
                    filterSection(title: "Trạng Thái", icon: "clock") {
                        statusSelection
                    }

                    // MARK: - Sort
                    filterSection(title: "Sắp Xếp", icon: "arrow.up.arrow.down") {
                        sortSelection
                    }
                }
                .padding(DesignTokens.Spacing.lg)
            }
            .navigationTitle("Bộ Lọc")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if viewModel.hasActiveFilters {
                        Button("Xoá tất cả") {
                            viewModel.clearFilters()
                        }
                        .foregroundStyle(themeManager.colors.brand)
                        .font(ThemeFont.body(size: 12, weight: .bold))
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Xong") {
                        dismiss()
                    }
                    .font(ThemeFont.body(size: 17, weight: .semibold))
                }
            }
        }
    }

    // MARK: - Active Filters Chips

    private var activeFiltersSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("Đang lọc")
                .font(ThemeFont.body(size: 12, weight: .bold))
                .foregroundStyle(themeManager.colors.textMuted)
                .textCase(.uppercase)
                .tracking(1)

            FlowLayoutCompact(spacing: 6) {
                if !viewModel.searchText.isEmpty {
                    FilterChip(
                        label: "\"\(viewModel.searchText)\"",
                        onRemove: {
                            viewModel.searchText = ""
                            viewModel.searchChanged()
                        }
                    )
                }

                ForEach(Array(viewModel.selectedGenreSlugs).sorted(), id: \.self) { slug in
                    let name = viewModel.genres.first(where: { $0.slug == slug })?.name ?? slug
                    FilterChip(label: name) {
                        viewModel.toggleGenre(slug)
                    }
                }

                ForEach(Array(viewModel.selectedRegionSlugs).sorted(), id: \.self) { slug in
                    let name = viewModel.regions.first(where: { $0.slug == slug })?.name ?? slug
                    FilterChip(label: name) {
                        viewModel.toggleRegion(slug)
                    }
                }

                if viewModel.selectedType != .all && viewModel.lockedType == nil {
                    FilterChip(label: viewModel.selectedType.label) {
                        viewModel.setType(.all)
                    }
                }

                if viewModel.selectedStatus != .all {
                    FilterChip(label: viewModel.selectedStatus.label) {
                        viewModel.setStatus(.all)
                    }
                }
            }
        }
        .padding(DesignTokens.Spacing.md)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.large))
    }

    // MARK: - Collapsible Multi-Select

    /// Reusable component for genre/region: shows top N items collapsed, full searchable list expanded.
    /// Selected items always pinned at top regardless of collapse state.
    @ViewBuilder
    private func collapsibleMultiSelect(
        items: [TagItem],
        selected: Set<String>,
        isExpanded: Binding<Bool>,
        searchText: Binding<String>,
        isLoading: Bool,
        onToggle: @escaping (String) -> Void
    ) -> some View {
        // Partition: selected first, then unselected
        let selectedItems = items.filter { selected.contains($0.slug) }
        let unselectedItems = items.filter { !selected.contains($0.slug) }

        // Filtered items when expanded + searching
        let filteredUnselected: [TagItem] = {
            let query = searchText.wrappedValue.lowercased()
            if query.isEmpty { return unselectedItems }
            return unselectedItems.filter { $0.name.lowercased().contains(query) }
        }()

        // Collapsed: selected + top N unselected
        let collapsedItems = selectedItems + Array(unselectedItems.prefix(max(0, maxCollapsedItems - selectedItems.count)))
        let remainingCount = unselectedItems.count - max(0, maxCollapsedItems - selectedItems.count)

        if isLoading {
            FlowLayoutCompact(spacing: DesignTokens.Spacing.sm) {
                ForEach(Array([80, 65, 95, 70, 88, 75].enumerated()), id: \.offset) { _, width in
                    RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.medium)
                        .fill(.quaternary)
                        .frame(width: CGFloat(width), height: 32)
                        .shimmer()
                }
            }
        } else {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                if isExpanded.wrappedValue {
                    // MARK: Expanded Mode

                    // Inline search
                    HStack(spacing: DesignTokens.Spacing.sm) {
                        Image(systemName: AppIcon.magnifyingglass)
                            .font(ThemeFont.body(size: 13))
                            .foregroundStyle(themeManager.colors.textMuted)
                        TextField("Tìm kiếm...", text: searchText)
                            .font(ThemeFont.body(size: 14))
                            .textFieldStyle(.plain)
                        if !searchText.wrappedValue.isEmpty {
                            Button {
                                searchText.wrappedValue = ""
                            } label: {
                                Image(systemName: AppIcon.xmarkCircleFill)
                                    .font(ThemeFont.body(size: 14))
                                    .foregroundStyle(themeManager.colors.textMuted)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, DesignTokens.Spacing.sm)
                    .background(themeManager.colors.overlaySubtle)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    // Selected items (always visible on top)
                    if !selectedItems.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Đã chọn (\(selectedItems.count))")
                                .font(ThemeFont.body(size: 11, weight: .bold))
                                .foregroundStyle(themeManager.colors.textMuted)
                                .textCase(.uppercase)
                                .tracking(0.5)

                            FlowLayoutCompact(spacing: DesignTokens.Spacing.sm) {
                                ForEach(selectedItems, id: \.slug) { item in
                                    tagButton(item: item, isSelected: true, onToggle: onToggle)
                                }
                            }
                        }
                    }

                    // All unselected filtered items
                    if filteredUnselected.isEmpty {
                        Text("Không tìm thấy")
                            .font(ThemeFont.body(size: 12))
                            .foregroundStyle(themeManager.colors.textMuted)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, DesignTokens.Spacing.md)
                    } else {
                        FlowLayoutCompact(spacing: DesignTokens.Spacing.sm) {
                            ForEach(filteredUnselected, id: \.slug) { item in
                                tagButton(item: item, isSelected: false, onToggle: onToggle)
                            }
                        }
                    }

                    // Collapse button
                    Button {
                        withAnimation(DesignTokens.Animation.standard) {
                            isExpanded.wrappedValue = false
                            searchText.wrappedValue = ""
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: AppIcon.chevronUp)
                                .font(ThemeFont.body(size: 10, weight: .bold))
                            Text("Thu gọn")
                                .font(ThemeFont.body(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(themeManager.colors.textMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignTokens.Spacing.sm)
                        .background(themeManager.colors.overlaySubtle)
                        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.medium))
                    }
                    .buttonStyle(.plain)
                } else {
                    // MARK: Collapsed Mode

                    FlowLayoutCompact(spacing: DesignTokens.Spacing.sm) {
                        ForEach(collapsedItems, id: \.slug) { item in
                            tagButton(
                                item: item,
                                isSelected: selected.contains(item.slug),
                                onToggle: onToggle
                            )
                        }
                    }

                    // "Show More" button
                    if remainingCount > 0 {
                        Button {
                            withAnimation(DesignTokens.Animation.standard) {
                                isExpanded.wrappedValue = true
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: AppIcon.chevronDown)
                                    .font(ThemeFont.body(size: 10, weight: .bold))
                                Text("Xem thêm \(remainingCount) mục")
                                    .font(ThemeFont.body(size: 12, weight: .semibold))
                            }
                            .foregroundStyle(themeManager.colors.brand)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DesignTokens.Spacing.sm)
                            .background(themeManager.colors.brand.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.medium))
                            .overlay {
                                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.medium)
                                    .strokeBorder(themeManager.colors.brand.opacity(0.12), lineWidth: 1)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Tag Button

    private func tagButton(item: TagItem, isSelected: Bool, onToggle: @escaping (String) -> Void) -> some View {
        Button {
            onToggle(item.slug)
        } label: {
            HStack(spacing: 4) {
                if isSelected {
                    Image(systemName: AppIcon.checkmark)
                        .font(ThemeFont.body(size: 9, weight: .bold))
                }
                Text(item.name)
                    .font(ThemeFont.body(size: 13, weight: isSelected ? .bold : .medium))
                if !isSelected, let count = item.count, count > 0 {
                    Text(formatCount(count))
                        .font(ThemeFont.body(size: 10))
                        .foregroundStyle(themeManager.colors.textMuted)
                }
            }
            .foregroundStyle(isSelected ? .white : themeManager.colors.textPrimary)
            .padding(.horizontal, isSelected ? 8 : 10)
            .padding(.vertical, 6)
            .background(
                isSelected
                    ? AnyShapeStyle(themeManager.colors.brand)
                    : AnyShapeStyle(themeManager.colors.overlaySubtle)
            )
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.medium))
            .overlay {
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.medium)
                    .strokeBorder(
                        isSelected ? themeManager.colors.brand.opacity(0.5) : themeManager.colors.border.opacity(0.3),
                        lineWidth: 1
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(item.name)\(isSelected ? ", đã chọn" : "")")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// Format large counts: 12998 → "12.9K"
    private func formatCount(_ count: Int) -> String {
        if count >= 10_000 {
            return String(format: "%.1fK", Double(count) / 1000)
        }
        return "\(count)"
    }

    // MARK: - Type Selection

    private var typeSelection: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            ForEach(BrowseTypeFilter.allCases) { typeFilter in
                Button {
                    viewModel.setType(typeFilter)
                } label: {
                    Label(typeFilter.label, systemImage: typeFilter.icon)
                        .font(ThemeFont.body(size: 13, weight: viewModel.selectedType == typeFilter ? .bold : .medium))
                        .foregroundStyle(viewModel.selectedType == typeFilter ? .white : themeManager.colors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            viewModel.selectedType == typeFilter
                                ? AnyShapeStyle(themeManager.colors.brand)
                                : AnyShapeStyle(themeManager.colors.overlaySubtle)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(typeFilter.label)
                .accessibilityAddTraits(viewModel.selectedType == typeFilter ? .isSelected : [])
            }
        }
    }

    // MARK: - Status Selection

    private var statusSelection: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            ForEach(BrowseStatusFilter.allCases) { statusFilter in
                Button {
                    viewModel.setStatus(statusFilter)
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: statusFilter.icon)
                            .font(ThemeFont.body(size: 16))
                        Text(statusFilter.label)
                            .font(ThemeFont.body(size: 11, weight: .medium))
                    }
                    .foregroundStyle(viewModel.selectedStatus == statusFilter ? .white : themeManager.colors.textMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        viewModel.selectedStatus == statusFilter
                            ? AnyShapeStyle(themeManager.colors.brand)
                            : AnyShapeStyle(themeManager.colors.overlaySubtle)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(statusFilter.label)
                .accessibilityAddTraits(viewModel.selectedStatus == statusFilter ? .isSelected : [])
            }
        }
    }

    // MARK: - Sort Selection

    private var sortSelection: some View {
        VStack(spacing: 2) {
            ForEach(BrowseSortOption.allCases) { option in
                Button {
                    viewModel.setSort(option)
                } label: {
                    HStack {
                        Text(option.label)
                            .font(ThemeFont.body(size: 14, weight: viewModel.sortOption == option ? .semibold : .regular))
                            .foregroundStyle(viewModel.sortOption == option ? themeManager.colors.textPrimary : themeManager.colors.textMuted)
                        Spacer()
                        if viewModel.sortOption == option {
                            Image(systemName: AppIcon.checkmark)
                                .font(ThemeFont.body(size: 12, weight: .bold))
                                .foregroundStyle(themeManager.colors.brand)
                        }
                    }
                    .padding(.horizontal, DesignTokens.Spacing.md)
                    .padding(.vertical, DesignTokens.Spacing.sm)
                    .background(
                        viewModel.sortOption == option
                            ? themeManager.colors.overlaySubtle
                            : Color.clear
                    )
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.medium))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(option.label)
                .accessibilityAddTraits(viewModel.sortOption == option ? .isSelected : [])
            }
        }
    }

    // MARK: - Section Wrapper

    private func filterSection<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: icon)
                    .font(ThemeFont.body(size: 12))
                    .foregroundStyle(themeManager.colors.brand)
                Text(title)
                    .font(ThemeFont.display(size: 15, weight: .bold))
                    .textCase(.uppercase)
                    .tracking(1)
            }

            content()
        }
    }
}

// MARK: - Tag Item (internal data model for collapsible multi-select)

private struct TagItem {
    let slug: String
    let name: String
    let count: Int?
}

// MARK: - Filter Chip

private struct FilterChip: View {
    let label: String
    let onRemove: () -> Void

    @Environment(\.themeManager) private var themeManager

    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(ThemeFont.body(size: 12, weight: .bold))
                .textCase(.uppercase)
                .tracking(0.5)

            Button {
                onRemove()
            } label: {
                Image(systemName: AppIcon.xmark)
                    .font(ThemeFont.body(size: 10, weight: .bold))
                    .foregroundStyle(ThemeColor.textPrimary.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(themeManager.colors.brand)
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .padding(.vertical, DesignTokens.Spacing.xs)
        .background(themeManager.colors.brand.opacity(0.12))
        .clipShape(Capsule())
        .overlay {
            Capsule()
                .strokeBorder(themeManager.colors.brand.opacity(0.2), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Bộ lọc \(label)")
        .accessibilityHint("Nhấn để xoá bộ lọc này")
    }
}

// MARK: - Preview

#Preview("Browse Filter Sheet") {
    BrowseFilterSheet(viewModel: BrowseViewModel())
        .preferredColorScheme(.dark)
}
