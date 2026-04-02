//
//  DateFormatting.swift
//  MovieStreamingApple
//
//  Centralized date formatting utility with cached DateFormatter instances.
//  Replaces duplicated formatters across PersonDetailViewModel,
//  DetailOverviewView, and DetailEpisodesView.
//

import Foundation

enum DateFormatting {
    // MARK: - Cached Formatters (DateFormatter is expensive to create)

    /// Input formatter for "yyyy-MM-dd" strings.
    private static let inputFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    /// Input formatter for ISO8601 full-date.
    private static let isoDateFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f
    }()

    /// Input formatter for ISO8601 with time + fractional seconds.
    private static let isoFullFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    /// Vietnamese long date (e.g., "ngày 15 tháng 3 năm 2024").
    private static let viLongFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "vi_VN")
        f.dateStyle = .long
        return f
    }()

    /// Vietnamese medium date (e.g., "15 thg 3, 2024").
    private static let viMediumFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "vi_VN")
        f.dateStyle = .medium
        return f
    }()

    /// Vietnamese short date (e.g., "15/03/2024").
    private static let viShortFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "vi_VN")
        f.dateFormat = "dd/MM/yyyy"
        return f
    }()

    // MARK: - Public API

    /// Parse a "yyyy-MM-dd" date string.
    static func parseDate(_ string: String) -> Date? {
        inputFormatter.date(from: string)
    }

    /// Parse an ISO8601 date string (tries full-date first, then full datetime).
    static func parseISO(_ string: String) -> Date? {
        isoDateFormatter.date(from: string)
            ?? isoFullFormatter.date(from: string)
    }

    /// Format a "yyyy-MM-dd" string to Vietnamese long date.
    static func formatLong(_ dateString: String) -> String? {
        guard let date = parseDate(dateString) else { return nil }
        return viLongFormatter.string(from: date)
    }

    /// Format an ISO8601 string to Vietnamese medium date.
    static func formatMedium(_ dateString: String) -> String {
        guard let date = parseISO(dateString) else { return dateString }
        return viMediumFormatter.string(from: date)
    }

    /// Format an ISO8601 string to Vietnamese short date (dd/MM/yyyy).
    static func formatShort(_ dateString: String) -> String {
        guard let date = parseISO(dateString) else { return dateString }
        return viShortFormatter.string(from: date)
    }

    /// Calculate age from "yyyy-MM-dd" birthDate.
    static func calculateAge(from birthDateString: String) -> Int? {
        guard let born = parseDate(birthDateString) else { return nil }
        let years = Calendar.current.dateComponents([.year], from: born, to: Date()).year ?? 0
        return years > 0 ? years : nil
    }

    /// Extract year from a date string prefix (first 4 chars).
    static func extractYear(_ dateString: String?) -> Int {
        guard let dateString else { return 0 }
        return Int(String(dateString.prefix(4))) ?? 0
    }
}
