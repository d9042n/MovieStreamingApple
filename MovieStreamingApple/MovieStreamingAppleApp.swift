//
//  MovieStreamingAppleApp.swift
//  MovieStreamingApple
//
//  Created by Lê Anh Đoàn on 24/3/26.
//

import SwiftUI

@main
struct MovieStreamingAppleApp: App {
    @State private var themeManager = ThemeManager()
    @State private var appRouter = AppRouter()
    @State private var watchHistoryManager = WatchHistoryManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.themeManager, themeManager)
                .environment(appRouter)
                .environment(watchHistoryManager)
        }
    }
}
