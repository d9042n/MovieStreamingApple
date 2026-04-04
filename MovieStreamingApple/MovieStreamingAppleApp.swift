//
//  MovieStreamingAppleApp.swift
//  MovieStreamingApple
//
//  Created by Lê Anh Đoàn on 24/3/26.
//

import SwiftUI

@main
struct MovieStreamingAppleApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @State private var themeManager = ThemeManager()
    @State private var appRouter = AppRouter()
    @State private var watchHistoryManager = WatchHistoryManager()

    /// Controls splash screen visibility. Starts `true` — splash is dismissed
    /// after video playback completes and data has been preloaded.
    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            // Main content — renders underneath splash so it's ready
            // when the splash fades out. HomeView's .task triggers
            // its own fetch, but URLSession cache is already warm.
            ContentView()
                .environment(\.themeManager, themeManager)
                .environment(appRouter)
                .environment(watchHistoryManager)
                .overlay {
                    // Splash overlay — fullscreen video + data prefetch.
                    // Uses .ignoresSafeArea() to extend beyond safe area, plus the
                    // UIViewController inside handles safe area inset compensation.
                    if showSplash {
                        SplashScreenView(isPresented: $showSplash)
                            .ignoresSafeArea()
                            .transition(.identity)
                    }
                }
        }
    }
}
