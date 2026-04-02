//
//  ContentView.swift
//  MovieStreamingApple
//
//  Root tab-based navigation with adaptive layout.
//
//  ┌──────────────────────────────────────────────────────────────────────┐
//  │ iPhone (.compact)  → Standard bottom tab bar                        │
//  │ iPad   (.regular)  → Floating top bar / expandable sidebar          │
//  │ iOS 26+            → Automatic Liquid Glass on both                 │
//  └──────────────────────────────────────────────────────────────────────┘
//
//  Uses .tabViewStyle(.sidebarAdaptable) — Apple's native adaptive nav.
//  On iPhone: renders as standard tab bar.
//  On iPad: renders as floating top bar that expands into a sidebar.
//
//  Navigation behavior:
//  - Switching to ANY tab → pop to root (NavigationPath reset)
//  - Re-tapping same tab → also pop to root
//

import SwiftUI

struct ContentView: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.themeManager) private var themeManager

    var body: some View {
        TabView(selection: tabSelection) {
            Tab("Trang chủ", systemImage: AppIcon.house, value: .home) {
                NavigationStack(path: Bindable(router).homePath) {
                    HomeView()
                        .toolbarVisibility(.hidden, for: .navigationBar)
                }
            }

            Tab("Tìm kiếm", systemImage: AppIcon.magnifyingglass, value: .search) {
                NavigationStack(path: Bindable(router).searchPath) {
                    BrowseView()
                }
            }

            Tab("Đang Xem", systemImage: AppIcon.playFill, value: .watching) {
                NavigationStack(path: Bindable(router).watchingPath) {
                    WatchingHubView()
                        .toolbarVisibility(.hidden, for: .navigationBar)
                }
            }

            Tab("Nghệ Sĩ", systemImage: AppIcon.person2Fill, value: .people) {
                NavigationStack(path: Bindable(router).peoplePath) {
                    PeopleView()
                }
            }

            Tab("Hồ sơ", systemImage: AppIcon.personCropCircleFill, value: .profile) {
                NavigationStack(path: Bindable(router).profilePath) {
                    ProfileView()
                }
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .tint(themeManager.colors.brand)
        .preferredColorScheme(.dark)
    }

    // MARK: - Tab Selection Binding (pop-to-root on every switch)

    private var tabSelection: Binding<AppTab> {
        Binding(
            get: { router.selectedTab },
            set: { newTab in
                if newTab == router.selectedTab {
                    router.popToRoot(for: newTab)
                } else {
                    router.popToRoot(for: newTab)
                    router.selectedTab = newTab
                }
            }
        )
    }
}

// MARK: - App Tab

enum AppTab: String, CaseIterable, Sendable {
    case home
    case search
    case watching
    case people
    case profile

    var next: AppTab? {
        let all = AppTab.allCases
        guard let index = all.firstIndex(of: self), index + 1 < all.count else { return nil }
        return all[index + 1]
    }

    var previous: AppTab? {
        let all = AppTab.allCases
        guard let index = all.firstIndex(of: self), index > 0 else { return nil }
        return all[index - 1]
    }
}

#Preview {
    ContentView()
        .environment(\.themeManager, ThemeManager())
        .environment(AppRouter())
        .environment(WatchHistoryManager())
}
