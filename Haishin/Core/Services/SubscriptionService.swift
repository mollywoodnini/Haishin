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

    /// Subscribes to a video.
    /// - Parameters:
    ///   - id: The video ID.
    ///   - title: The video title.
    ///   - coverURL: The cover image URL.
    ///   - sourceId: The source ID used to fetch episodes.
    func subscribe(id: String, title: String, coverURL: URL?, sourceId: String)

    /// Unsubscribes from a video.
    func unsubscribe(id: String)

    /// Checks if a video is subscribed.
    func isSubscribed(id: String) -> Bool

    /// Gets the count of subscribed videos.
    func getSubscribedCount() -> Int
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

    private struct Constants {
        static let storageKey = "subscribedVideo"
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

    func subscribe(id: String, title: String, coverURL: URL?, sourceId: String) {
        var allSubscribed = loadAllSubscribed()

        guard !allSubscribed.contains(where: { $0.id == id }) else { return }

        let newSubscription = SubscribedVideo(id: id,
                                              title: title,
                                              coverURL: coverURL,
                                              sourceId: sourceId,
                                              subscribedAt: Date())
        allSubscribed.append(newSubscription)
        persistAllSubscribed(allSubscribed)
        triggerCloudSync()
    }

    func unsubscribe(id: String) {
        var allSubscribed = loadAllSubscribed()
        allSubscribed.removeAll { $0.id == id }
        persistAllSubscribed(allSubscribed)
        triggerCloudSync()
    }

    func isSubscribed(id: String) -> Bool {
        loadAllSubscribed().contains { $0.id == id }
    }

    func getSubscribedCount() -> Int {
        loadAllSubscribed().count
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

    private func triggerCloudSync() {
        // Use the shared instance directly to avoid circular initialization
        CloudSyncService.shared.syncToCloud()
    }
}
