//
//  SubscriptionService.swift
//  Miru
//
//  Created by Miru on 25.01.26.
//

import Foundation


//#################################################################################
// MARK: - SubscribedAnime
//#################################################################################

/// Represents an anime the user has subscribed to for updates.
struct SubscribedAnime: Codable, Identifiable, Equatable {

    /// The anime ID (from AniList).
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
    /// Gets all subscribed anime sorted by subscription date.
    func getSubscribedAnime() -> [SubscribedAnime]

    /// Subscribes to an anime.
    func subscribe(id: Int, title: String, coverURL: URL?)

    /// Unsubscribes from an anime.
    func unsubscribe(id: Int)

    /// Checks if an anime is subscribed.
    func isSubscribed(id: Int) -> Bool

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


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new subscription service.
    /// - Parameter userDefaults: The UserDefaults instance to use for persistence.
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }


    //#################################################################################
    // MARK: - Public Methods
    //#################################################################################

    func getSubscribedAnime() -> [SubscribedAnime] {
        loadAllSubscribed().sorted { $0.subscribedAt > $1.subscribedAt }
    }

    func subscribe(id: Int, title: String, coverURL: URL?) {
        var allSubscribed = loadAllSubscribed()

        guard !allSubscribed.contains(where: { $0.id == id }) else { return }

        let newSubscription = SubscribedAnime(id: id,
                                              title: title,
                                              coverURL: coverURL,
                                              subscribedAt: Date())
        allSubscribed.append(newSubscription)
        persistAllSubscribed(allSubscribed)
    }

    func unsubscribe(id: Int) {
        var allSubscribed = loadAllSubscribed()
        allSubscribed.removeAll { $0.id == id }
        persistAllSubscribed(allSubscribed)
    }

    func isSubscribed(id: Int) -> Bool {
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
}
