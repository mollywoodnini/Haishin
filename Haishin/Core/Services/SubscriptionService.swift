//
//  SubscriptionService.swift
//  Haishin
//
//  Created by Tan Nghia La on 25.01.26.
//

import Foundation


//#################################################################################
// MARK: - SubscribedVideo
//#################################################################################

/// Represents a video the user has subscribed to for updates.
struct SubscribedVideo: VideoProtocol, Codable, Equatable {

    /// The video ID.
    let id: String

    /// The video title.
    let title: String

    /// URL to the cover image.
    let coverURL: URL?

    /// The source ID used to fetch episodes.
    let sourceId: String

    /// The direct URL to the video details page (for direct navigation without search).
    let detailsURL: String?

    /// Date when the user subscribed.
    var subscribedAt: Date
}


//#################################################################################
// MARK: - SubscribedAnime
//#################################################################################

/// Represents an anime the user has subscribed to from AniList browsing.
struct SubscribedAnime: Codable, Identifiable, Equatable, Hashable {

    /// The AniList anime ID.
    let id: Int

    /// The anime title.
    let title: String

    /// URL to the cover image.
    let coverURL: URL?

    /// Date when the user subscribed.
    var subscribedAt: Date
}


//#################################################################################
// MARK: - SubscriptionServiceProtocol
//#################################################################################

/// Protocol for subscription management.
@MainActor
protocol SubscriptionServiceProtocol {
    /// Gets all subscribed videos sorted by subscription date.
    func getSubscribedVideo() -> [SubscribedVideo]

    /// Gets the count of subscribed videos.
    func getSubscribedCount() -> Int

    /// Gets all subscribed anime sorted by subscription date.
    func getSubscribedAnime() -> [SubscribedAnime]

    /// Subscribes to an anime from AniList.
    /// - Parameters:
    ///   - id: The AniList anime ID.
    ///   - title: The anime title.
    ///   - coverURL: The anime cover image URL.
    func subscribeAnime(id: Int, title: String, coverURL: URL?)

    /// Unsubscribes from an AniList anime.
    /// - Parameter id: The AniList anime ID.
    func unsubscribeAnime(id: Int)

    /// Checks if an AniList anime is subscribed.
    /// - Parameter id: The AniList anime ID.
    func isAnimeSubscribed(id: Int) -> Bool

    /// Gets the count of subscribed anime.
    func getSubscribedAnimeCount() -> Int
}


//#################################################################################
// MARK: - SubscriptionService
//#################################################################################

/// Service for managing video subscriptions using UserDefaults.
@MainActor
final class SubscriptionService: SubscriptionServiceProtocol {

    //#################################################################################
    // MARK: - Constants
    //#################################################################################

    private enum Constants {
        static let storageKey = "subscribedVideo"
        static let animeStorageKey = "subscribedAnime"
    }


    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    /// Shared instance for app-wide use.
    static let shared = SubscriptionService()

    private let userDefaults: UserDefaults
    private let cloudSyncService: CloudSyncServiceProtocol?


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new subscription service.
    /// - Parameters:
    ///   - userDefaults: The UserDefaults instance to use for persistence.
    ///   - cloudSyncService: The cloud sync service for iCloud sync.
    init(userDefaults: UserDefaults = .standard,
         cloudSyncService: CloudSyncServiceProtocol? = nil) {
        self.userDefaults = userDefaults
        // Use provided service or default to shared instance (lazy to avoid circular init)
        self.cloudSyncService = cloudSyncService
    }


    //#################################################################################
    // MARK: - Public Methods
    //#################################################################################

    func getSubscribedVideo() -> [SubscribedVideo] {
        loadAllSubscribed().sorted { $0.subscribedAt > $1.subscribedAt }
    }

    func getSubscribedCount() -> Int {
        loadAllSubscribed().count
    }

    func getSubscribedAnime() -> [SubscribedAnime] {
        loadAllSubscribedAnime().sorted { $0.subscribedAt > $1.subscribedAt }
    }

    func subscribeAnime(id: Int, title: String, coverURL: URL?) {
        var allSubscribed = loadAllSubscribedAnime()
        guard !allSubscribed.contains(where: { $0.id == id }) else { return }
        let newSubscription = SubscribedAnime(id: id, title: title, coverURL: coverURL, subscribedAt: Date())
        allSubscribed.append(newSubscription)
        persistAllSubscribedAnime(allSubscribed)
        triggerCloudSync()
    }

    func unsubscribeAnime(id: Int) {
        var allSubscribed = loadAllSubscribedAnime()
        allSubscribed.removeAll { $0.id == id }
        persistAllSubscribedAnime(allSubscribed)
        triggerCloudSync()
    }

    func isAnimeSubscribed(id: Int) -> Bool {
        loadAllSubscribedAnime().contains { $0.id == id }
    }

    func getSubscribedAnimeCount() -> Int {
        loadAllSubscribedAnime().count
    }


    //#################################################################################
    // MARK: - Private Methods
    //#################################################################################

    private func loadAllSubscribed() -> [SubscribedVideo] {
        guard let data = userDefaults.data(forKey: Constants.storageKey),
              let decoded = try? JSONDecoder().decode([SubscribedVideo].self, from: data) else {
            return []
        }
        return decoded
    }

    private func persistAllSubscribed(_ subscribed: [SubscribedVideo]) {
        guard let encoded = try? JSONEncoder().encode(subscribed) else { return }
        userDefaults.set(encoded, forKey: Constants.storageKey)
    }

    private func loadAllSubscribedAnime() -> [SubscribedAnime] {
        guard let data = userDefaults.data(forKey: Constants.animeStorageKey),
              let decoded = try? JSONDecoder().decode([SubscribedAnime].self, from: data) else {
            return []
        }
        return decoded
    }

    private func persistAllSubscribedAnime(_ subscribed: [SubscribedAnime]) {
        guard let encoded = try? JSONEncoder().encode(subscribed) else { return }
        userDefaults.set(encoded, forKey: Constants.animeStorageKey)
    }

    private func triggerCloudSync() {
        // Use the shared instance directly to avoid circular initialization
        CloudSyncService.shared.syncToCloud()
    }
}
