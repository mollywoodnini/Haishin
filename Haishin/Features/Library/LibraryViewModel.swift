//
//  LibraryViewModel.swift
//  Haishin
//
//  Created by Tan Nghia La on 24.01.26.
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

    /// Returns the source name for a given source ID.
    /// - Parameter sourceId: The source ID to look up.
    /// - Returns: The source name, or nil if the source is not installed.
    func sourceName(for sourceId: String) -> String? {
        sourceManager.installedSources.first { $0.id == sourceId }?.info.name
    }


    //#################################################################################
    // MARK: - Child ViewModel Factory Methods
    //#################################################################################

    /// Creates an EpisodeListViewModel for any anime conforming to AnimeProtocol.
    /// - Parameter anime: The anime to show episodes for.
    /// - Returns: A new `EpisodeListViewModel` for the anime, or nil if the source is not installed.
    func makeEpisodeListViewModel(anime: some AnimeProtocol) -> EpisodeListViewModel? {
        // Verify the source is still installed
        guard sourceManager.installedSources.contains(where: { $0.id == anime.sourceId }) else {
            return nil
        }
        return EpisodeListViewModel(mode: .online(anime: anime, detailsURL: nil),
                                    sourceManager: sourceManager,
                                    watchProgressService: watchProgressService,
                                    subscriptionService: subscriptionService,
                                    downloadService: downloadService)
    }

    /// Creates an EpisodeListViewModel for a downloaded anime.
    /// - Parameter anime: The downloaded anime to show episodes for.
    /// - Returns: A new `EpisodeListViewModel` for the downloaded anime.
    func makeEpisodeListViewModel(downloadedAnime anime: DownloadedAnime) -> EpisodeListViewModel {
        EpisodeListViewModel(mode: .offline(anime),
                             sourceManager: sourceManager,
                             watchProgressService: watchProgressService,
                             subscriptionService: subscriptionService,
                             downloadService: downloadService)
    }
}
