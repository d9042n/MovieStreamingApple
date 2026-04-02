//
//  String+Extensions.swift
//  MovieStreamingApple
//
//  Shared String utilities used across the app.
//

import Foundation

extension String {
    /// Strips HTML tags from a string using regex replacement.
    var strippingHTML: String {
        replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
