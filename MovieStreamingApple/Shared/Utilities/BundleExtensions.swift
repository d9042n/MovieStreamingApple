//
//  BundleExtensions.swift
//  MovieStreamingApple
//
//  Convenience accessors for app metadata from Info.plist.
//

import Foundation

extension Bundle {
    /// Marketing version (CFBundleShortVersionString), e.g. "1.2.0"
    var appVersion: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "–"
    }

    /// Build number (CFBundleVersion), e.g. "42"
    var buildNumber: String {
        infoDictionary?["CFBundleVersion"] as? String ?? "–"
    }

    /// Combined display string, e.g. "1.2.0 (42)"
    var fullVersionString: String {
        "\(appVersion) (\(buildNumber))"
    }
}
