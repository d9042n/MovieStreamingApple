//
//  CustomTabBarView.swift
//  MovieStreamingApple
//
//  Custom tab bar overlay — iOS 18–25 ONLY.
//  On iOS 26+, we use the NATIVE tab bar which gets Liquid Glass automatically.
//
//  This view is only rendered via `if #unavailable(iOS 26)` in ContentView.
//  Safe area: Uses GeometryReader for proper bottom inset.
//

import SwiftUI

struct CustomTabBarView: View {
    @Binding var selectedTab: AppTab
    @Environment(\.themeManager) private var themeManager

    /// Controls visibility — set to true when WatchView / fullscreen player is active.
    var isHidden: Bool = false

    private let tabBarHeight: CGFloat = 60
    private let centerButtonSize: CGFloat = 52
    private let centerButtonOffset: CGFloat = -14

    var body: some View {
        if !isHidden {
            GeometryReader { geometry in
                let bottomInset = geometry.safeAreaInsets.bottom

                VStack(spacing: 0) {
                    Spacer()

                    tabBarContent(bottomInset: bottomInset)
                }
                .ignoresSafeArea(edges: .bottom)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(DesignTokens.Animation.quick, value: isHidden)
        }
    }

    // MARK: - Tab Bar Content (iOS 18–25 material blur)

    private func tabBarContent(bottomInset: CGFloat) -> some View {
        HStack(spacing: 0) {
            tabItem(tab: .home, icon: AppIcon.house, activeIcon: AppIcon.houseFill, label: "Trang chủ")
            tabItem(tab: .search, icon: AppIcon.magnifyingglass, activeIcon: AppIcon.magnifyingglass, label: "Tìm kiếm")
            centerButton
            tabItem(tab: .people, icon: AppIcon.person2, activeIcon: AppIcon.person2Fill, label: "Nghệ Sĩ")
            tabItem(tab: .profile, icon: AppIcon.personCropCircleFill, activeIcon: AppIcon.personCropCircleFill, label: "Hồ sơ")
        }
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .padding(.bottom, bottomInset)
        .frame(height: tabBarHeight + bottomInset)
        .background {
            ZStack {
                Rectangle()
                    .fill(.ultraThinMaterial)
                Rectangle()
                    .fill(ThemeColor.bgCard.opacity(0.7))
            }
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(themeManager.colors.border.opacity(0.3))
                    .frame(height: 0.5)
            }
        }
    }

    // MARK: - Regular Tab Item

    private func tabItem(tab: AppTab, icon: String, activeIcon: String, label: String) -> some View {
        Button {
            withAnimation(DesignTokens.Animation.quick) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: DesignTokens.Spacing.xs) {
                Image(systemName: selectedTab == tab ? activeIcon : icon)
                    .font(ThemeFont.body(size: 20))
                    .symbolRenderingMode(.monochrome)
                    .frame(height: 24)

                Text(label)
                    .font(ThemeFont.body(size: 10, weight: .medium))
            }
            .foregroundStyle(
                selectedTab == tab
                    ? themeManager.colors.brand
                    : themeManager.colors.textMuted
            )
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(selectedTab == tab ? [.isSelected] : [])
    }

    // MARK: - Center Button (Elevated)

    private var centerButton: some View {
        Button {
            withAnimation(DesignTokens.Animation.spring) {
                selectedTab = .watching
            }
        } label: {
            VStack(spacing: DesignTokens.Spacing.xs) {
                ZStack {
                    Circle()
                        .fill(themeManager.colors.brand)
                        .frame(width: centerButtonSize, height: centerButtonSize)
                        .shadow(
                            color: themeManager.colors.brand.opacity(selectedTab == .watching ? 0.5 : 0.2),
                            radius: selectedTab == .watching ? 12 : 6,
                            y: 2
                        )

                    Image(systemName: AppIcon.playFill)
                        .font(ThemeFont.display(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                }
                .offset(y: centerButtonOffset)
                .scaleEffect(selectedTab == .watching ? 1.05 : 1.0)
                .animation(DesignTokens.Animation.spring, value: selectedTab)

                Text("Đang Xem")
                    .font(ThemeFont.body(size: 10, weight: .semibold))
                    .foregroundStyle(
                        selectedTab == .watching
                            ? themeManager.colors.brand
                            : themeManager.colors.textMuted
                    )
                    .offset(y: centerButtonOffset)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Đang Xem")
        .accessibilityAddTraits(selectedTab == .watching ? [.isSelected] : [])
    }
}

// MARK: - Preview

#Preview("Custom Tab Bar (iOS 18–25)") {
    ZStack(alignment: .bottom) {
        Color.black.ignoresSafeArea()
        VStack {
            Text("Content Area")
                .foregroundStyle(.white)
            Spacer()
        }
        CustomTabBarView(selectedTab: .constant(.watching))
    }
    .environment(\.themeManager, ThemeManager())
}
