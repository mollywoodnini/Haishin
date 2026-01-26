//
//  SubtitleRenderer.swift
//  Haishin
//
//  Created by OpenCode on 26.01.26.
//

import Foundation


//#################################################################################
// MARK: - SubtitleCue
//#################################################################################

/// Represents a single subtitle cue with timing and text.
struct SubtitleCue: Identifiable {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    /// Unique identifier.
    let id: String

    /// Start time in seconds.
    let startTime: TimeInterval

    /// End time in seconds.
    let endTime: TimeInterval

    /// The subtitle text content.
    let text: String
}


//#################################################################################
// MARK: - SubtitleRenderer
//#################################################################################

/// Parses and manages subtitle display for video playback.
@Observable
@MainActor
final class SubtitleRenderer {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    /// The currently visible subtitle text (empty if none).
    private(set) var currentText: String = ""

    /// All parsed subtitle cues.
    private(set) var cues: [SubtitleCue] = []

    /// Whether subtitles are currently loading.
    private(set) var isLoading = false

    /// Error that occurred during loading.
    private(set) var error: Error?

    private var loadTask: Task<Void, Never>?


    //#################################################################################
    // MARK: - Public Methods
    //#################################################################################

    /// Loads subtitles from the given URL.
    /// - Parameter url: The URL to the subtitle file (WebVTT or SRT format).
    func load(from url: URL) {
        loadTask?.cancel()
        cues = []
        currentText = ""
        error = nil
        isLoading = true

        loadTask = Task { [weak self] in
            do {
                let (data, _) = try await URLSession.shared.data(from: url)

                guard !Task.isCancelled else { return }

                guard let content = String(data: data, encoding: .utf8) else {
                    throw SubtitleError.invalidFormat
                }

                let parsedCues = self?.parseSubtitles(content) ?? []

                await MainActor.run {
                    self?.cues = parsedCues
                    self?.isLoading = false
                    Log.debug(.playback, "Loaded \(parsedCues.count) subtitle cues")
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self?.error = error
                    self?.isLoading = false
                    Log.error(.playback, "Failed to load subtitles: \(error)")
                }
            }
        }
    }

    /// Updates the current subtitle text based on playback time.
    /// - Parameter time: The current playback time in seconds.
    func update(for time: TimeInterval) {
        // Find the cue that matches the current time
        let matchingCue = cues.first { cue in
            time >= cue.startTime && time < cue.endTime
        }

        currentText = matchingCue?.text ?? ""
    }

    /// Clears all loaded subtitles.
    func clear() {
        loadTask?.cancel()
        loadTask = nil
        cues = []
        currentText = ""
        error = nil
        isLoading = false
    }


    //#################################################################################
    // MARK: - Private Methods
    //#################################################################################

    private func parseSubtitles(_ content: String) -> [SubtitleCue] {
        // Detect format and parse accordingly
        if content.contains("WEBVTT") {
            return parseWebVTT(content)
        } else {
            return parseSRT(content)
        }
    }

    private func parseWebVTT(_ content: String) -> [SubtitleCue] {
        var cues: [SubtitleCue] = []
        let lines = content.components(separatedBy: .newlines)

        var currentStartTime: TimeInterval?
        var currentEndTime: TimeInterval?
        var currentText: [String] = []
        var cueIndex = 0

        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)

            // Skip WEBVTT header and notes
            if trimmedLine.hasPrefix("WEBVTT") || trimmedLine.hasPrefix("NOTE") || trimmedLine.isEmpty {
                // If we have a pending cue, save it
                if let startTime = currentStartTime, let endTime = currentEndTime, !currentText.isEmpty {
                    let text = currentText.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                    if !text.isEmpty {
                        cues.append(SubtitleCue(id: "cue-\(cueIndex)",
                                                startTime: startTime,
                                                endTime: endTime,
                                                text: cleanSubtitleText(text)))
                        cueIndex += 1
                    }
                    currentStartTime = nil
                    currentEndTime = nil
                    currentText = []
                }
                continue
            }

            // Check for timestamp line (contains "-->")
            if trimmedLine.contains("-->") {
                // Save previous cue if exists
                if let startTime = currentStartTime, let endTime = currentEndTime, !currentText.isEmpty {
                    let text = currentText.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                    if !text.isEmpty {
                        cues.append(SubtitleCue(id: "cue-\(cueIndex)",
                                                startTime: startTime,
                                                endTime: endTime,
                                                text: cleanSubtitleText(text)))
                        cueIndex += 1
                    }
                    currentText = []
                }

                // Parse new timestamp
                let times = parseTimestampLine(trimmedLine)
                currentStartTime = times.start
                currentEndTime = times.end
            } else if currentStartTime != nil {
                // This is subtitle text (skip cue identifiers which are typically just numbers)
                if !trimmedLine.allSatisfy({ $0.isNumber }) {
                    currentText.append(trimmedLine)
                }
            }
        }

        // Don't forget the last cue
        if let startTime = currentStartTime, let endTime = currentEndTime, !currentText.isEmpty {
            let text = currentText.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                cues.append(SubtitleCue(id: "cue-\(cueIndex)",
                                        startTime: startTime,
                                        endTime: endTime,
                                        text: cleanSubtitleText(text)))
            }
        }

        return cues
    }

    private func parseSRT(_ content: String) -> [SubtitleCue] {
        // SRT format is similar to WebVTT but uses commas instead of periods for milliseconds
        // Convert to WebVTT-like format and parse
        let webvttContent = content.replacingOccurrences(of: ",", with: ".")
        return parseWebVTT("WEBVTT\n\n" + webvttContent)
    }

    private func parseTimestampLine(_ line: String) -> (start: TimeInterval, end: TimeInterval) {
        let parts = line.components(separatedBy: "-->")
        guard parts.count == 2 else { return (0, 0) }

        let startStr = parts[0].trimmingCharacters(in: .whitespaces)
        let endStr = parts[1].trimmingCharacters(in: .whitespaces).components(separatedBy: " ").first ?? ""

        return (parseTimestamp(startStr), parseTimestamp(endStr))
    }

    private func parseTimestamp(_ timestamp: String) -> TimeInterval {
        // Format: HH:MM:SS.mmm or MM:SS.mmm
        let cleanTimestamp = timestamp.trimmingCharacters(in: .whitespaces)
        let parts = cleanTimestamp.components(separatedBy: ":")

        var hours: Double = 0
        var minutes: Double = 0
        var seconds: Double = 0

        if parts.count == 3 {
            hours = Double(parts[0]) ?? 0
            minutes = Double(parts[1]) ?? 0
            seconds = Double(parts[2]) ?? 0
        } else if parts.count == 2 {
            minutes = Double(parts[0]) ?? 0
            seconds = Double(parts[1]) ?? 0
        }

        return hours * 3600 + minutes * 60 + seconds
    }

    private func cleanSubtitleText(_ text: String) -> String {
        // Remove common formatting tags like <i>, <b>, <c.colorClass>, etc.
        var cleaned = text

        // Remove HTML-like tags
        let tagPattern = #"<[^>]+>"#
        cleaned = cleaned.replacingOccurrences(of: tagPattern, with: "", options: .regularExpression)

        // Decode HTML entities
        cleaned = cleaned.decodingHTMLEntities()

        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}


//#################################################################################
// MARK: - SubtitleError
//#################################################################################

enum SubtitleError: LocalizedError {
    case invalidFormat
    case networkError

    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "Invalid subtitle format"
        case .networkError:
            return "Failed to load subtitles"
        }
    }
}
