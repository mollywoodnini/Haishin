//
//  SubscriptionService.swift
//  Haishin
//
//  Created by Haishin on 25.01.26.
//

import Foundation


//#################################################################################
// MARK: - SubscribedAnime
//#################################################################################

/// Represents an anime the user has subscribed to for updates.
struct SubscribedAnime: AnimeProtocol, Codable, Equatable {

    /// The anime ID.
    let id: String

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
    /// Gets all subscribed anime sorted by subscription date.
    func getSubscribedAnime() -> [SubscribedAnime]

    /// Subscribes to an anime.
    func subscribe(id: String, title: String, coverURL: URL?)

    /// Unsubscribes from an anime.
    func unsubscribe(id: String)

    /// Checks if an anime is subscribed.
    func isSubscribed(id: String) -> Bool

    /// Gets the count of subscribed anime.
    func getSubscribedCount() -> Int
}


//#################################################################################
// MARK: - SubscriptionService
//#################################################################################

/// Service for managing anime subscriptions using UserDefaults.
@MainActor
final class SubscriptionService: SubscriptionServiceProtocol {

    //#################################################################################
    // MARK: - Constants
    //#################################################################################

    private struct Constants {
        static let storageKey = "subscribedAnime"
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

    func getSubscribedAnime() -> [SubscribedAnime] {
        loadAllSubscribed().sorted { $0.subscribedAt > $1.subscribedAt }
    }

    func subscribe(id: String, title: String, coverURL: URL?) {
        var allSubscribed = loadAllSubscribed()

        guard !allSubscribed.contains(where: { $0.id == id }) else { return }

        let newSubscription = SubscribedAnime(id: id,
                                              title: title,
                                              coverURL: coverURL,
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

    private func loadAllSubscribed() -> [SubscribedAnime] {
        guard let data = userDefaults.data(forKey: Constants.storageKey),
              let decoded = try? JSONDecoder().decode([SubscribedAnime].self, from: data) else {
            return []
        }
        return decoded
    }

    private func persistAllSubscribed(_ subscribed: [SubscribedAnime]) {
        guard let encoded = try? JSONEncoder().encode(subscribed) else { return }
        userDefaults.set(encoded, forKey: Constants.storageKey)
    }

    private func triggerCloudSync() {
        // Use the shared instance directly to avoid circular initialization
        CloudSyncService.shared.syncToCloud()
    }
}
