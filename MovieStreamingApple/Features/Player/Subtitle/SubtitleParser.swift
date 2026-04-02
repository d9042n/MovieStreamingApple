//
//  SubtitleParser.swift
//  MovieStreamingApple
//
//  Async subtitle file parser supporting WebVTT (.vtt) and SRT (.srt) formats.
//  Downloads the subtitle file from URL, parses timestamps and text,
//  and returns sorted [SubtitleCue] for the player overlay.
//

import Foundation
import os

private let logger = Logger(subsystem: "com.d9042n.moviestreaming", category: "SubtitleParser")

enum SubtitleParserError: LocalizedError, Sendable {
    case invalidURL(String)
    case downloadFailed(Error)
    case emptyContent
    case parseError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL(let url): return "URL phụ đề không hợp lệ: \(url)"
        case .downloadFailed(let error): return "Không thể tải phụ đề: \(error.localizedDescription)"
        case .emptyContent: return "File phụ đề trống"
        case .parseError(let detail): return "Lỗi phân tích phụ đề: \(detail)"
        }
    }
}

/// Parses WebVTT and SRT subtitle files into an array of `SubtitleCue`.
enum SubtitleParser {

    /// Downloads and parses a subtitle file from a URL string.
    ///
    /// - Parameter urlString: The URL of the subtitle file (.vtt or .srt).
    /// - Returns: Sorted array of `SubtitleCue` by start time.
    /// - Throws: `SubtitleParserError` on failure.
    static func parse(from urlString: String) async throws -> [SubtitleCue] {
        guard let url = URL(string: urlString) else {
            throw SubtitleParserError.invalidURL(urlString)
        }

        let content: String
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let text = String(data: data, encoding: .utf8) else {
                throw SubtitleParserError.emptyContent
            }
            content = text
        } catch let error as SubtitleParserError {
            throw error
        } catch {
            throw SubtitleParserError.downloadFailed(error)
        }

        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SubtitleParserError.emptyContent
        }

        // Detect format by content or URL extension
        let isVTT = content.hasPrefix("WEBVTT") || urlString.lowercased().hasSuffix(".vtt")

        let cues: [SubtitleCue]
        if isVTT {
            cues = parseWebVTT(content)
        } else {
            cues = parseSRT(content)
        }

        logger.info("Parsed \(cues.count) subtitle cues from \(url.lastPathComponent)")
        return cues.sorted { $0.startTime < $1.startTime }
    }

    // MARK: - WebVTT Parser

    /// Parses WebVTT formatted content.
    ///
    /// WebVTT format:
    /// ```
    /// WEBVTT
    ///
    /// 00:00:01.000 --> 00:00:04.000
    /// Hello world
    ///
    /// 00:00:05.000 --> 00:00:08.000
    /// Second subtitle line
    /// ```
    private static func parseWebVTT(_ content: String) -> [SubtitleCue] {
        var cues: [SubtitleCue] = []
        var cueIndex = 0

        // Split into blocks separated by blank lines
        let blocks = content.components(separatedBy: "\n\n")

        for block in blocks {
            let lines = block.components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            // Skip WEBVTT header, NOTE blocks, STYLE blocks
            guard !lines.isEmpty else { continue }
            if lines[0].hasPrefix("WEBVTT") || lines[0].hasPrefix("NOTE") || lines[0].hasPrefix("STYLE") {
                continue
            }

            // Find the timestamp line (contains "-->")
            guard let timestampLineIndex = lines.firstIndex(where: { $0.contains("-->") }) else {
                continue
            }

            let timestampLine = lines[timestampLineIndex]
            guard let (startTime, endTime) = parseTimestampLine(timestampLine) else {
                continue
            }

            // Collect text lines after the timestamp line
            let textLines = Array(lines[(timestampLineIndex + 1)...])
            let text = textLines.joined(separator: "\n")
                .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression) // Strip VTT tags
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !text.isEmpty else { continue }

            cues.append(SubtitleCue(id: cueIndex, startTime: startTime, endTime: endTime, text: text))
            cueIndex += 1
        }

        return cues
    }

    // MARK: - SRT Parser

    /// Parses SRT (SubRip) formatted content.
    ///
    /// SRT format:
    /// ```
    /// 1
    /// 00:00:01,000 --> 00:00:04,000
    /// Hello world
    ///
    /// 2
    /// 00:00:05,000 --> 00:00:08,000
    /// Second subtitle line
    /// ```
    private static func parseSRT(_ content: String) -> [SubtitleCue] {
        var cues: [SubtitleCue] = []
        var cueIndex = 0

        // Normalize line endings and split into blocks
        let normalized = content
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        let blocks = normalized.components(separatedBy: "\n\n")

        for block in blocks {
            let lines = block.components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            guard lines.count >= 2 else { continue }

            // Find the timestamp line (SRT uses comma for milliseconds)
            guard let timestampLineIndex = lines.firstIndex(where: { $0.contains("-->") }) else {
                continue
            }

            let timestampLine = lines[timestampLineIndex]
                .replacingOccurrences(of: ",", with: ".") // Normalize SRT comma → dot

            guard let (startTime, endTime) = parseTimestampLine(timestampLine) else {
                continue
            }

            // Text is everything after the timestamp line
            let textLines = Array(lines[(timestampLineIndex + 1)...])
            let text = textLines.joined(separator: "\n")
                .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression) // Strip HTML tags
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !text.isEmpty else { continue }

            cues.append(SubtitleCue(id: cueIndex, startTime: startTime, endTime: endTime, text: text))
            cueIndex += 1
        }

        return cues
    }

    // MARK: - Timestamp Parsing

    /// Parses a timestamp line like "00:01:23.456 --> 00:01:27.890"
    /// Returns (startTime, endTime) in seconds, or nil on failure.
    private static func parseTimestampLine(_ line: String) -> (TimeInterval, TimeInterval)? {
        let parts = line.components(separatedBy: "-->")
        guard parts.count == 2 else { return nil }

        let startStr = parts[0].trimmingCharacters(in: .whitespaces)
        let endStr = parts[1]
            .trimmingCharacters(in: .whitespaces)
            .components(separatedBy: " ").first ?? "" // Remove position settings after timestamp

        guard let start = parseTimestamp(startStr),
              let end = parseTimestamp(endStr) else {
            return nil
        }

        return (start, end)
    }

    /// Parses a single timestamp like "00:01:23.456" or "01:23.456" to TimeInterval.
    private static func parseTimestamp(_ timestamp: String) -> TimeInterval? {
        let clean = timestamp.trimmingCharacters(in: .whitespaces)
        let parts = clean.components(separatedBy: ":")

        switch parts.count {
        case 2:
            // MM:SS.mmm
            guard let minutes = Double(parts[0]),
                  let seconds = Double(parts[1]) else { return nil }
            return minutes * 60 + seconds

        case 3:
            // HH:MM:SS.mmm
            guard let hours = Double(parts[0]),
                  let minutes = Double(parts[1]),
                  let seconds = Double(parts[2]) else { return nil }
            return hours * 3600 + minutes * 60 + seconds

        default:
            return nil
        }
    }
}
