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
    var downloadsCount: Int { downloadService.totalDownloadsCount }

    private let watchProgressService: WatchProgressServiceProtocol
    private let subscriptionService: SubscriptionServiceProtocol
    private let sourceManager: SourceManaging
    private let downloadService: DownloadServiceProtocol
    private let userPreferences: UserPreferencesProtocol
    private let aniListService: AniListServicing


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new library view model.
    /// - Parameters:
    ///   - watchProgressService: The service for accessing watch progress and recents.
    ///   - subscriptionService: The service for managing subscriptions.
    ///   - sourceManager: The source manager for episode fetching.
    ///   - downloadService: The service for managing downloads.
    ///   - userPreferences: The user preferences.
    ///   - aniListService: The service to fetch anime details.
    init(watchProgressService: WatchProgressServiceProtocol,
         subscriptionService: SubscriptionServiceProtocol,
         sourceManager: SourceManaging,
         downloadService: DownloadServiceProtocol,
         userPreferences: UserPreferencesProtocol,
         aniListService: AniListServicing) {
        self.watchProgressService = watchProgressService
        self.subscriptionService = subscriptionService
        self.sourceManager = sourceManager
        self.downloadService = downloadService
        self.userPreferences = userPreferences
        self.aniListService = aniListService
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

    /// Removes a recent anime from the list.
    /// - Parameter id: The anime ID to remove.
    func removeRecentAnime(id: Int) {
        watchProgressService.removeRecentAnime(id: id)
        recentAnime.removeAll { $0.id == id }
    }

    /// Unsubscribes from an anime.
    /// - Parameter id: The anime ID to unsubscribe from.
    func unsubscribe(id: Int) {
        subscriptionService.unsubscribe(id: id)
        subscribedAnime.removeAll { $0.id == id }
    }


    //#################################################################################
    // MARK: - Child ViewModel Factory Methods
    //#################################################################################

    /// Creates an AnimeDetailViewModel for a recent anime.
    /// - Parameter anime: The recent anime to show details for.
    /// - Returns: A new `AnimeDetailViewModel` for the anime.
    func makeAnimeDetailViewModel(recentAnime anime: RecentAnime) -> AnimeDetailViewModel {
        AnimeDetailViewModel(mode: .raw(animeId: anime.id,
                                        title: anime.title,
                                        coverURL: anime.coverURL),
                             aniListService: aniListService,
                             subscriptionService: subscriptionService,
                             watchProgressService: watchProgressService,
                             sourceManager: sourceManager,
                             userPreferences: userPreferences)
    }

    /// Creates an AnimeDetailViewModel for a subscribed anime.
    /// - Parameter anime: The subscribed anime to show details for.
    /// - Returns: A new `AnimeDetailViewModel` for the anime.
    func makeAnimeDetailViewModel(subscribedAnime anime: SubscribedAnime) -> AnimeDetailViewModel {
        AnimeDetailViewModel(mode: .raw(animeId: anime.id,
                                        title: anime.title,
                                        coverURL: anime.coverURL),
                             aniListService: aniListService,
                             subscriptionService: subscriptionService,
                             watchProgressService: watchProgressService,
                             sourceManager: sourceManager,
                             userPreferences: userPreferences)
    }
}
