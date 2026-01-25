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
    private let sourceManager: SourceManaging?


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new library view model.
    /// - Parameters:
    ///   - watchProgressService: The service for accessing watch progress and recents.
    ///   - subscriptionService: The service for managing subscriptions.
    ///   - sourceManager: The source manager for episode fetching.
    init(watchProgressService: WatchProgressServiceProtocol,
         subscriptionService: SubscriptionServiceProtocol,
         sourceManager: SourceManaging? = nil) {
        self.watchProgressService = watchProgressService
        self.subscriptionService = subscriptionService
        self.sourceManager = sourceManager
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


    //#################################################################################
    // MARK: - Child ViewModel Factory Methods
    //#################################################################################

    /// Creates an AnimeDetailViewModel for a recent anime.
    /// - Parameter anime: The recent anime to show details for.
    /// - Returns: A new `AnimeDetailViewModel` for the anime.
    func makeAnimeDetailViewModel(recentAnime anime: RecentAnime) -> AnimeDetailViewModel {
        AnimeDetailViewModel(animeId: anime.id,
                             previewTitle: anime.title,
                             previewCoverURL: anime.coverURL,
                             subscriptionService: subscriptionService,
                             watchProgressService: watchProgressService,
                             sourceManager: sourceManager)
    }

    /// Creates an AnimeDetailViewModel for a subscribed anime.
    /// - Parameter anime: The subscribed anime to show details for.
    /// - Returns: A new `AnimeDetailViewModel` for the anime.
    func makeAnimeDetailViewModel(subscribedAnime anime: SubscribedAnime) -> AnimeDetailViewModel {
        AnimeDetailViewModel(animeId: anime.id,
                             previewTitle: anime.title,
                             previewCoverURL: anime.coverURL,
                             subscriptionService: subscriptionService,
                             watchProgressService: watchProgressService,
                             sourceManager: sourceManager)
    }
}
