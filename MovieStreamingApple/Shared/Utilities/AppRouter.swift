import SwiftUI

@Observable
@MainActor
final class AppRouter {
    var selectedTab: AppTab = .home
    var isPlayerActive: Bool = false
    
    // Explicit NavigationPaths per tab
    var homePath = NavigationPath()
    var searchPath = NavigationPath()
    var watchingPath = NavigationPath()
    var peoplePath = NavigationPath()
    var profilePath = NavigationPath()
    
    // Cross-tab communication state
    var browseTargetGenreSlug: String? = nil
    
    func navigateToBrowse(genreSlug: String) {
        // Pop the browse tab to root first so it starts fresh
        searchPath = NavigationPath()
        
        // Set the target genre
        browseTargetGenreSlug = genreSlug
        
        // Switch to the search (browse) tab
        selectedTab = .search
    }
    
    func popToRoot(for tab: AppTab) {
        switch tab {
        case .home:
            homePath = NavigationPath()
        case .search:
            searchPath = NavigationPath()
        case .watching:
            watchingPath = NavigationPath()
        case .people:
            peoplePath = NavigationPath()
        case .profile:
            profilePath = NavigationPath()
        }
    }
}

