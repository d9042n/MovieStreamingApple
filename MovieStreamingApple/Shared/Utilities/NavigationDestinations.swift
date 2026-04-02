import Foundation

/// Navigation value types used across features for value-based NavigationLink.
/// SwiftUI NavigationStack with a bound path works reliably only with
/// value-based NavigationLink + .navigationDestination. The old
/// `NavigationLink(destination:)` pattern can fail silently.

/// Navigates to a person detail page.
struct PersonDestination: Hashable {
    let slug: String
}

/// Navigates to a content detail page (from filmography, related, etc.).
struct ContentDestination: Hashable {
    let slug: String
    let type: ContentType
}

/// Navigates to the watch/player page.
struct PlayerDestination: Hashable {
    let slug: String
    let type: ContentType
    var episodeId: String?
    var seasonNumber: Int?
    var episodeNumber: Int?
    var autoResume: Bool = false
}
