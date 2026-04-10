//
//  SkipContentSettings.swift
//  MovieStreamingApple
//
//  Skip intro & outro settings with per-content UserDefaults persistence.
//  Follows SubtitleSettings pattern: @Observable, didSet auto-save,
//  debounced writes, dictionary serialization.
//
//  Storage: keyed by content slug. When set for a series,
//  the setting applies to all episodes of that series.
//
//  TODO: When backend API provides per-episode intro/outro timestamps,
//  those values should take priority over user-configured durations.
//  See `suggestedIntroDuration` / `suggestedOutroDuration` placeholders.
//

import SwiftUI
import os

private let logger = Logger(subsystem: "com.d9042n.moviestreaming", category: "SkipContentSettings")

// MARK: - Skip Duration Option

/// A selectable skip duration preset.
struct SkipDurationOption: Identifiable {
    let label: String
    let duration: TimeInterval

    var id: TimeInterval { duration }
}

// MARK: - SkipContentSettings Model

/// Observable skip content settings with per-content UserDefaults persistence.
@Observable
@MainActor
final class SkipContentSettings {

    // MARK: - Properties

    /// Duration (in seconds) to skip at the beginning of playback.
    var introSkipDuration: TimeInterval = 0 {
        didSet { saveIfNeeded() }
    }

    /// Duration (in seconds) to skip at the end of playback.
    var outroSkipDuration: TimeInterval = 0 {
        didSet { saveIfNeeded() }
    }

    // MARK: - TODO: Backend API Suggested Values
    //
    // When API provides per-episode intro/outro timestamps:
    //   suggestedIntroDuration = response.introEnd - response.introStart
    //   suggestedOutroDuration = response.outroEnd - response.outroStart
    //
    // Priority hierarchy:
    //   1. API metadata per-episode (future) — highest
    //   2. User per-content setting (current workaround)
    //   3. Default (Off / 0s)

    /// Suggested intro skip duration from backend API (nil = not available).
    var suggestedIntroDuration: TimeInterval? = nil

    /// Suggested outro skip duration from backend API (nil = not available).
    var suggestedOutroDuration: TimeInterval? = nil

    // MARK: - Content Binding

    /// The content slug this instance is bound to.
    private(set) var contentSlug: String = ""

    // MARK: - Persistence

    private static let keyPrefix = "skip_content_"

    /// Debounce task for UserDefaults writes.
    private var saveTask: Task<Void, Never>?

    /// Suppresses save during load to avoid circular writes.
    private var isSuppressingSave = false

    // MARK: - Preset Options

    /// Available skip duration presets (shared for both intro and outro).
    static let presets: [SkipDurationOption] = [
        SkipDurationOption(label: String(localized: "Tắt"), duration: 0),
        SkipDurationOption(label: String(localized: "15 giây"), duration: 15),
        SkipDurationOption(label: String(localized: "30 giây"), duration: 30),
        SkipDurationOption(label: String(localized: "45 giây"), duration: 45),
        SkipDurationOption(label: String(localized: "1 phút"), duration: 60),
        SkipDurationOption(label: String(localized: "1 phút 30"), duration: 90),
        SkipDurationOption(label: String(localized: "2 phút"), duration: 120),
        SkipDurationOption(label: String(localized: "2 phút 30"), duration: 150),
        SkipDurationOption(label: String(localized: "3 phút"), duration: 180),
    ]

    /// Maximum allowed custom value (seconds).
    static let maxCustomDuration: TimeInterval = 300

    // MARK: - Init

    init() {}

    // MARK: - Content Binding

    /// Load skip settings for a specific content (by slug).
    /// Call when the player loads a new source.
    func loadForContent(slug: String) {
        contentSlug = slug
        load()
    }

    // MARK: - Actions

    /// Reset both intro and outro to defaults (Tắt).
    func resetToDefaults() {
        introSkipDuration = 0
        outroSkipDuration = 0
    }

    // MARK: - Display Helpers

    /// Human-readable duration label (e.g., "1 phút 30" or "Tắt").
    static func formatDuration(_ seconds: TimeInterval) -> String {
        guard seconds > 0 else { return String(localized: "Tắt") }
        let total = Int(seconds)
        let mins = total / 60
        let secs = total % 60
        if mins > 0 && secs > 0 {
            return "\(mins) phút \(secs)"
        } else if mins > 0 {
            return "\(mins) phút"
        }
        return "\(total) giây"
    }

    /// Short format for summary labels (e.g., "1:30" or "Tắt").
    static func shortFormat(_ seconds: TimeInterval) -> String {
        guard seconds > 0 else { return String(localized: "Tắt") }
        let total = Int(seconds)
        let mins = total / 60
        let secs = total % 60
        if mins > 0 {
            return String(format: "%d:%02d", mins, secs)
        }
        return "\(total)s"
    }

    /// Summary text for the settings sheet entry.
    var summaryLabel: String {
        let introOff = introSkipDuration <= 0
        let outroOff = outroSkipDuration <= 0
        if introOff && outroOff { return String(localized: "Tắt") }
        var parts: [String] = []
        if !introOff { parts.append("I: \(Self.shortFormat(introSkipDuration))") }
        if !outroOff { parts.append("O: \(Self.shortFormat(outroSkipDuration))") }
        return parts.joined(separator: " · ")
    }

    // MARK: - Private Persistence

    private var storageKey: String {
        "\(Self.keyPrefix)\(contentSlug)"
    }

    private func saveIfNeeded() {
        guard !isSuppressingSave else { return }
        save()
    }

    private func save() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled, let self else { return }
            self.performSave()
        }
    }

    private func performSave() {
        guard !contentSlug.isEmpty else { return }
        let data: [String: Any] = [
            "introSkipDuration": introSkipDuration,
            "outroSkipDuration": outroSkipDuration,
        ]
        UserDefaults.standard.set(data, forKey: storageKey)
        logger.info("Saved skip settings for '\(self.contentSlug)': intro=\(self.introSkipDuration)s, outro=\(self.outroSkipDuration)s")
    }

    private func load() {
        isSuppressingSave = true
        defer { isSuppressingSave = false }

        guard !contentSlug.isEmpty,
              let data = UserDefaults.standard.dictionary(forKey: storageKey) else {
            introSkipDuration = 0
            outroSkipDuration = 0
            return
        }

        if let v = data["introSkipDuration"] as? Double { introSkipDuration = v }
        if let v = data["outroSkipDuration"] as? Double { outroSkipDuration = v }
        logger.info("Loaded skip settings for '\(self.contentSlug)': intro=\(self.introSkipDuration)s, outro=\(self.outroSkipDuration)s")
    }
}
