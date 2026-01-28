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

    /// The anime ID.
    let animeId: String

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
// MARK: - RecentAnime
//#################################################################################

/// Represents a recently watched anime with minimal info for display.
struct RecentAnime: AnimeProtocol, Codable, Equatable {

    /// The anime ID.
    let id: String

    /// The anime title.
    let title: String

    /// URL to the cover image.
    let coverURL: URL?

    /// The source ID used to fetch this anime.
    let sourceId: String

    /// Date when the anime was last watched.
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
    func getProgress(animeId: String, episodeId: String) -> WatchProgress?

    /// Gets all watch progress for an anime.
    func getAllProgress(animeId: String) -> [WatchProgress]

    /// Saves or updates watch progress for an episode.
    func saveProgress(_ progress: WatchProgress)

    /// Removes watch progress for a specific episode.
    func removeProgress(animeId: String, episodeId: String)

    /// Clears all watch progress for an anime.
    func clearAllProgress(animeId: String)

    /// Gets all recent anime sorted by last watched date.
    func getRecentAnime() -> [RecentAnime]

    /// Adds or updates a recent anime entry.
    /// - Parameters:
    ///   - id: The anime ID.
    ///   - title: The anime title.
    ///   - coverURL: The cover image URL.
    ///   - sourceId: The source ID used to fetch this anime.
    ///   - episodeNumber: The last watched episode number.
    func updateRecentAnime(id: String, title: String, coverURL: URL?, sourceId: String, episodeNumber: String?)

    /// Gets the count of recent anime.
    func getRecentAnimeCount() -> Int

    /// Removes a recent anime entry.
    func removeRecentAnime(id: String)
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

    private struct Constants {
        static let storageKey = "watchProgress"
        static let recentAnimeKey = "recentAnime"
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

    func getProgress(animeId: String, episodeId: String) -> WatchProgress? {
        let allProgress = loadAllProgress()
        let key = makeKey(animeId: animeId, episodeId: episodeId)
        return allProgress[key]
    }

    func getAllProgress(animeId: String) -> [WatchProgress] {
        let allProgress = loadAllProgress()
        return allProgress.values.filter { $0.animeId == animeId }
    }

    func saveProgress(_ progress: WatchProgress) {
        var allProgress = loadAllProgress()
        let key = makeKey(animeId: progress.animeId, episodeId: progress.episodeId)
        allProgress[key] = progress
        persistAllProgress(allProgress)
        triggerCloudSync()
    }

    func removeProgress(animeId: String, episodeId: String) {
        var allProgress = loadAllProgress()
        let key = makeKey(animeId: animeId, episodeId: episodeId)
        allProgress.removeValue(forKey: key)
        persistAllProgress(allProgress)
        triggerCloudSync()
    }

    func clearAllProgress(animeId: String) {
        var allProgress = loadAllProgress()
        let keysToRemove = allProgress.keys.filter { $0.hasPrefix("\(animeId)_") }
        keysToRemove.forEach { allProgress.removeValue(forKey: $0) }
        persistAllProgress(allProgress)
        triggerCloudSync()
    }

    func getRecentAnime() -> [RecentAnime] {
        loadAllRecentAnime().sorted { $0.lastWatchedAt > $1.lastWatchedAt }
    }

    func updateRecentAnime(id: String, title: String, coverURL: URL?, sourceId: String, episodeNumber: String?) {
        var allRecent = loadAllRecentAnime()

        if let index = allRecent.firstIndex(where: { $0.id == id }) {
            allRecent[index].lastWatchedAt = Date()
            allRecent[index].lastEpisodeNumber = episodeNumber
        } else {
            let newRecent = RecentAnime(id: id,
                                        title: title,
                                        coverURL: coverURL,
                                        sourceId: sourceId,
                                        lastWatchedAt: Date(),
                                        lastEpisodeNumber: episodeNumber)
            allRecent.append(newRecent)
        }

        persistAllRecentAnime(allRecent)
        triggerCloudSync()
    }

    func getRecentAnimeCount() -> Int {
        loadAllRecentAnime().count
    }

    func removeRecentAnime(id: String) {
        var allRecent = loadAllRecentAnime()
        allRecent.removeAll { $0.id == id }
        persistAllRecentAnime(allRecent)
        triggerCloudSync()
    }


    //#################################################################################
    // MARK: - Private Methods
    //#################################################################################

    private func makeKey(animeId: String, episodeId: String) -> String {
        "\(animeId)_\(episodeId)"
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

    private func loadAllRecentAnime() -> [RecentAnime] {
        guard let data = userDefaults.data(forKey: Constants.recentAnimeKey),
              let decoded = try? JSONDecoder().decode([RecentAnime].self, from: data) else {
            return []
        }
        return decoded
    }

    private func persistAllRecentAnime(_ recentAnime: [RecentAnime]) {
        guard let encoded = try? JSONEncoder().encode(recentAnime) else { return }
        userDefaults.set(encoded, forKey: Constants.recentAnimeKey)
    }

    private func triggerCloudSync() {
        CloudSyncService.shared.syncToCloud()
    }
}
