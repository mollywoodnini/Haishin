//
//  WatchProgressService.swift
//  Haishin
//
//  Created by Tan Nghia La on 25.01.26.
//

import Foundation


//#################################################################################
// MARK: - WatchProgress
//#################################################################################

/// Represents the watch progress for a specific episode.
struct WatchProgress: Codable, Equatable {

    /// The video ID.
    let videoId: String

    /// The episode ID (from the source).
    let episodeId: String

    /// The episode number.
    let episodeNumber: String

    /// Current playback position in seconds.
    var currentTime: TimeInterval

    /// Total duration of the episode in seconds.
    var duration: TimeInterval

    /// Date when the progress was last updated.
    var lastUpdated: Date

    /// Progress as a percentage (0.0 to 1.0).
    var progress: Double {
        guard duration > 0 else { return 0 }
        return min(currentTime / duration, 1.0)
    }

    /// Whether the episode is considered completed (watched more than 90%).
    var isCompleted: Bool {
        progress >= 0.9
    }
}


//#################################################################################
// MARK: - RecentVideo
//#################################################################################

/// Represents a recently watched video with minimal info for display.
struct RecentVideo: VideoProtocol, Codable, Equatable {

    /// The video ID.
    let id: String

    /// The video title.
    let title: String

    /// URL to the cover image.
    let coverURL: URL?

    /// The source ID used to fetch this video.
    let sourceId: String

    /// The direct URL to the video details page.
    let detailsURL: String?

    /// Date when the video was last watched.
    var lastWatchedAt: Date

    /// The last watched episode number.
    var lastEpisodeNumber: String?
}




//#################################################################################
// MARK: - WatchProgressServiceProtocol
//#################################################################################

/// Protocol for watch progress persistence.
@MainActor
protocol WatchProgressServiceProtocol {
    /// Gets the watch progress for a specific episode.
    func getProgress(videoId: String, episodeId: String) -> WatchProgress?

    /// Gets all watch progress for a video.
    func getAllProgress(videoId: String) -> [WatchProgress]

    /// Saves or updates watch progress for an episode.
    func saveProgress(_ progress: WatchProgress)

    /// Removes watch progress for a specific episode.
    func removeProgress(videoId: String, episodeId: String)

    /// Clears all watch progress for a video.
    func clearAllProgress(videoId: String)

    /// Gets all recent videos sorted by last watched date.
    func getRecentVideo() -> [RecentVideo]

    /// Adds or updates a recent video entry.
    /// - Parameters:
    ///   - id: The video ID.
    ///   - title: The video title.
    ///   - coverURL: The cover image URL.
    ///   - sourceId: The source ID used to fetch this video.
    ///   - detailsURL: The direct URL to the video details page.
    ///   - episodeNumber: The last watched episode number.
    func updateRecentVideo(id: String,
                           title: String,
                           coverURL: URL?,
                           sourceId: String,
                           detailsURL: String?,
                           episodeNumber: String?)

    /// Gets the count of recent videos.
    func getRecentVideoCount() -> Int

    /// Removes a recent video entry.
    func removeRecentVideo(id: String)
}


//#################################################################################
// MARK: - WatchProgressService
//#################################################################################

/// Service for persisting episode watch progress using UserDefaults.
@MainActor
final class WatchProgressService: WatchProgressServiceProtocol {

    //#################################################################################
    // MARK: - Constants
    //#################################################################################

    private enum Constants {
        static let storageKey = "watchProgress"
        static let recentVideoKey = "recentVideo"
    }


    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    /// Shared instance for app-wide use.
    static let shared = WatchProgressService()

    private let userDefaults: UserDefaults


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new watch progress service.
    /// - Parameter userDefaults: The UserDefaults instance to use for persistence.
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }


    //#################################################################################
    // MARK: - Public Methods
    //#################################################################################

    func getProgress(videoId: String, episodeId: String) -> WatchProgress? {
        let allProgress = loadAllProgress()
        let key = makeKey(videoId: videoId, episodeId: episodeId)
        return allProgress[key]
    }

    func getAllProgress(videoId: String) -> [WatchProgress] {
        let allProgress = loadAllProgress()
        return allProgress.values.filter { $0.videoId == videoId }
    }

    func saveProgress(_ progress: WatchProgress) {
        var allProgress = loadAllProgress()
        let key = makeKey(videoId: progress.videoId, episodeId: progress.episodeId)
        allProgress[key] = progress
        persistAllProgress(allProgress)
        triggerCloudSync()
    }

    func removeProgress(videoId: String, episodeId: String) {
        var allProgress = loadAllProgress()
        let key = makeKey(videoId: videoId, episodeId: episodeId)
        allProgress.removeValue(forKey: key)
        persistAllProgress(allProgress)
        triggerCloudSync()
    }

    func clearAllProgress(videoId: String) {
        var allProgress = loadAllProgress()
        let keysToRemove = allProgress.keys.filter { $0.hasPrefix("\(videoId)_") }
        keysToRemove.forEach { allProgress.removeValue(forKey: $0) }
        persistAllProgress(allProgress)
        triggerCloudSync()
    }

    func getRecentVideo() -> [RecentVideo] {
        loadAllRecentVideo().sorted { $0.lastWatchedAt > $1.lastWatchedAt }
    }

    func updateRecentVideo(id: String,
                           title: String,
                           coverURL: URL?,
                           sourceId: String,
                           detailsURL: String?,
                           episodeNumber: String?) {
        var allRecent = loadAllRecentVideo()

        if let index = allRecent.firstIndex(where: { $0.id == id }) {
            allRecent[index].lastWatchedAt = Date()
            allRecent[index].lastEpisodeNumber = episodeNumber
        } else {
            let newRecent = RecentVideo(id: id,
                                        title: title,
                                        coverURL: coverURL,
                                        sourceId: sourceId,
                                        detailsURL: detailsURL,
                                        lastWatchedAt: Date(),
                                        lastEpisodeNumber: episodeNumber)
            allRecent.append(newRecent)
        }

        persistAllRecentVideo(allRecent)
        triggerCloudSync()
    }

    func getRecentVideoCount() -> Int {
        loadAllRecentVideo().count
    }

    func removeRecentVideo(id: String) {
        var allRecent = loadAllRecentVideo()
        allRecent.removeAll { $0.id == id }
        persistAllRecentVideo(allRecent)
        triggerCloudSync()
    }


    //#################################################################################
    // MARK: - Private Methods
    //#################################################################################

    private func makeKey(videoId: String, episodeId: String) -> String {
        "\(videoId)_\(episodeId)"
    }

    private func loadAllProgress() -> [String: WatchProgress] {
        guard let data = userDefaults.data(forKey: Constants.storageKey),
              let decoded = try? JSONDecoder().decode([String: WatchProgress].self, from: data) else {
            return [:]
        }
        return decoded
    }

    private func persistAllProgress(_ progress: [String: WatchProgress]) {
        guard let encoded = try? JSONEncoder().encode(progress) else { return }
        userDefaults.set(encoded, forKey: Constants.storageKey)
    }

    private func loadAllRecentVideo() -> [RecentVideo] {
        guard let data = userDefaults.data(forKey: Constants.recentVideoKey),
              let decoded = try? JSONDecoder().decode([RecentVideo].self, from: data) else {
            return []
        }
        return decoded
    }

    private func persistAllRecentVideo(_ recentVideo: [RecentVideo]) {
        guard let encoded = try? JSONEncoder().encode(recentVideo) else { return }
        userDefaults.set(encoded, forKey: Constants.recentVideoKey)
    }

    private func triggerCloudSync() {
        CloudSyncService.shared.syncToCloud()
    }
}
