//
//  LibraryViewModel.swift
//  Haishin
//
//  Created by Haishin on 24.01.26.
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

    /// All downloaded anime.
    private(set) var downloadedAnime: [DownloadedAnime] = []

    /// Count of recent anime.
    var recentsCount: Int { recentAnime.count }

    /// Count of subscribed anime.
    var subscribedCount: Int { subscribedAnime.count }

    /// Count of downloaded items.
    var downloadsCount: Int { downloadService.totalDownloadsCount }

    private let watchProgressService: WatchProgressServiceProtocol
    private let subscriptionService: SubscriptionServiceProtocol
    private let sourceManager: SourceManaging
    private let downloadService: DownloadServiceProtocol
    private let userPreferences: UserPreferencesProtocol


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
         userPreferences: UserPreferencesProtocol) {
        self.watchProgressService = watchProgressService
        self.subscriptionService = subscriptionService
        self.sourceManager = sourceManager
        self.downloadService = downloadService
        self.userPreferences = userPreferences
        refresh()
    }


    //#################################################################################
    // MARK: - Public Methods
    //#################################################################################

    /// Refreshes all library data.
    func refresh() {
        recentAnime = watchProgressService.getRecentAnime()
        subscribedAnime = subscriptionService.getSubscribedAnime()
        downloadedAnime = downloadService.downloadedAnime
    }

    /// Removes a recent anime from the list.
    /// - Parameter id: The anime ID to remove.
    func removeRecentAnime(id: String) {
        watchProgressService.removeRecentAnime(id: id)
        recentAnime.removeAll { $0.id == id }
    }

    /// Unsubscribes from an anime.
    /// - Parameter id: The anime ID to unsubscribe from.
    func unsubscribe(id: String) {
        subscriptionService.unsubscribe(id: id)
        subscribedAnime.removeAll { $0.id == id }
    }

    /// Removes all downloads for an anime.
    /// - Parameter animeId: The anime ID to remove downloads for.
    func removeAllDownloads(forAnimeId animeId: String) {
        downloadService.removeAllDownloads(forAnimeId: animeId)
        downloadedAnime.removeAll { $0.id == animeId }
    }


    //#################################################################################
    // MARK: - Child ViewModel Factory Methods
    //#################################################################################

    /// Creates an EpisodeListViewModel for a recent anime.
    /// - Parameter anime: The recent anime to show episodes for.
    /// - Returns: A new `EpisodeListViewModel` for the anime, or nil if no source is selected.
    func makeEpisodeListViewModel(recentAnime anime: RecentAnime) -> EpisodeListViewModel? {
        guard let sourceId = userPreferences.selectedSourceId else { return nil }
        return EpisodeListViewModel(animeId: anime.id,
                                    animeTitle: anime.title,
                                    animeCoverURL: anime.coverURL,
                                    sourceId: sourceId,
                                    sourceManager: sourceManager,
                                    watchProgressService: watchProgressService,
                                    subscriptionService: subscriptionService,
                                    downloadService: downloadService,
                                    userPreferences: userPreferences)
    }

    /// Creates an EpisodeListViewModel for a subscribed anime.
    /// - Parameter anime: The subscribed anime to show episodes for.
    /// - Returns: A new `EpisodeListViewModel` for the anime, or nil if no source is selected.
    func makeEpisodeListViewModel(subscribedAnime anime: SubscribedAnime) -> EpisodeListViewModel? {
        guard let sourceId = userPreferences.selectedSourceId else { return nil }
        return EpisodeListViewModel(animeId: anime.id,
                                    animeTitle: anime.title,
                                    animeCoverURL: anime.coverURL,
                                    sourceId: sourceId,
                                    sourceManager: sourceManager,
                                    watchProgressService: watchProgressService,
                                    subscriptionService: subscriptionService,
                                    downloadService: downloadService,
                                    userPreferences: userPreferences)
    }

    /// Creates an EpisodeListViewModel for a downloaded anime.
    /// - Parameter anime: The downloaded anime to show episodes for.
    /// - Returns: A new `EpisodeListViewModel` for the downloaded anime.
    func makeEpisodeListViewModel(downloadedAnime anime: DownloadedAnime) -> EpisodeListViewModel {
        EpisodeListViewModel(downloadedAnime: anime,
                             watchProgressService: watchProgressService,
                             downloadService: downloadService)
    }
}
