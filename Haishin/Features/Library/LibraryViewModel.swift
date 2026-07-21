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

    /// All recently watched videos.
    private(set) var recentVideo: [RecentVideo] = []

    /// All subscribed videos.
    private(set) var subscribedVideo: [SubscribedVideo] = []

    /// All subscribed anime from AniList.
    private(set) var subscribedAnime: [SubscribedAnime] = []

    /// All downloaded videos.
    private(set) var downloadedVideo: [DownloadedVideo] = []

    /// Count of recent videos.
    var recentsCount: Int { recentVideo.count }

    /// Count of subscribed videos.
    var subscribedCount: Int { subscribedVideo.count + subscribedAnime.count }

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
    ///   - userPreferences: The user preferences.
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
        recentVideo = watchProgressService.getRecentVideo()
        subscribedVideo = subscriptionService.getSubscribedVideo()
        subscribedAnime = subscriptionService.getSubscribedAnime()
        downloadedVideo = downloadService.downloadedVideo
    }

    /// Removes a recent video from the list.
    /// - Parameter id: The video ID to remove.
    func removeRecentVideo(id: String) {
        watchProgressService.removeRecentVideo(id: id)
        recentVideo.removeAll { $0.id == id }
    }

    /// Unsubscribes from an AniList anime.
    /// - Parameter id: The anime ID to unsubscribe from.
    func unsubscribeAnime(id: Int) {
        subscriptionService.unsubscribeAnime(id: id)
        subscribedAnime.removeAll { $0.id == id }
    }

    /// Subscribes to an AniList anime.
    /// - Parameters:
    ///   - id: The anime ID.
    ///   - title: The anime title.
    ///   - coverURL: The cover image URL.
    func subscribeAnime(id: Int, title: String, coverURL: URL?) {
        subscriptionService.subscribeAnime(id: id, title: title, coverURL: coverURL)
        refresh()
    }

    /// Removes all downloads for a video.
    /// - Parameter videoId: The video ID to remove downloads for.
    func removeAllDownloads(forVideoId videoId: String) {
        downloadService.removeAllDownloads(forVideoId: videoId)
        downloadedVideo.removeAll { $0.id == videoId }
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

    /// Creates an EpisodeListViewModel for any video conforming to VideoProtocol.
    /// - Parameter video: The video to show episodes for.
    /// - Returns: A new `EpisodeListViewModel` for the video, or nil if the source is not installed.
    func makeEpisodeListViewModel(video: some VideoProtocol) -> EpisodeListViewModel? {
        // Verify the source is still installed
        guard sourceManager.installedSources.contains(where: { $0.id == video.sourceId }) else {
            return nil
        }

        return EpisodeListViewModel(mode: .online(video: video),
                                    sourceManager: sourceManager,
                                    watchProgressService: watchProgressService,
                                    subscriptionService: subscriptionService,
                                    downloadService: downloadService)
    }

    /// Creates an EpisodeListViewModel for a downloaded video.
    /// - Parameter video: The downloaded video to show episodes for.
    /// - Returns: A new `EpisodeListViewModel` for the downloaded video.
    func makeEpisodeListViewModel(downloadedVideo video: DownloadedVideo) -> EpisodeListViewModel {
        EpisodeListViewModel(mode: .offline(video),
                             sourceManager: sourceManager,
                             watchProgressService: watchProgressService,
                             subscriptionService: subscriptionService,
                             downloadService: downloadService)
    }
}
