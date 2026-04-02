//
//  SubtitleCue.swift
//  MovieStreamingApple
//
//  A single parsed subtitle cue with timing and text content.
//  Used by SubtitleParser and rendered by SubtitleOverlayView.
//

import Foundation

/// A single parsed subtitle cue with start/end timestamps and text.
struct SubtitleCue: Identifiable, Sendable, Equatable {
    let id: Int
    let startTime: TimeInterval
    let endTime: TimeInterval
    let text: String

    /// Whether a given time falls within this cue's range.
    func isActive(at time: TimeInterval) -> Bool {
        time >= startTime && time < endTime
    }
}
