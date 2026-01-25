//
//  LibraryViewModel.swift
//  Miru
//
//  Created by Miru on 24.01.26.
//

import Foundation


//#################################################################################
// MARK: - LibraryViewModel
//#################################################################################

/// ViewModel for the library screen.
@Observable
@MainActor
final class LibraryViewModel {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    /// All recently watched anime.
    private(set) var recentAnime: [RecentAnime] = []

    /// All subscribed anime.
    private(set) var subscribedAnime: [SubscribedAnime] = []

    /// Count of recent anime.
    var recentsCount: Int { recentAnime.count }

    /// Count of subscribed anime.
    var subscribedCount: Int { subscribedAnime.count }

    /// Count of downloaded items (placeholder for now).
    var downloadsCount: Int { 0 }

    private let watchProgressService: WatchProgressServiceProtocol
    private let subscriptionService: SubscriptionServiceProtocol


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new library view model.
    /// - Parameters:
    ///   - watchProgressService: The service for accessing watch progress and recents.
    ///   - subscriptionService: The service for managing subscriptions.
    init(watchProgressService: WatchProgressServiceProtocol = WatchProgressService.shared,
         subscriptionService: SubscriptionServiceProtocol = SubscriptionService.shared) {
        self.watchProgressService = watchProgressService
        self.subscriptionService = subscriptionService
        refresh()
    }


    //#################################################################################
    // MARK: - Public Methods
    //#################################################################################

    /// Refreshes all library data.
    func refresh() {
        recentAnime = watchProgressService.getRecentAnime()
        subscribedAnime = subscriptionService.getSubscribedAnime()
    }
}
