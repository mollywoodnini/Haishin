//
//  SourceDetailViewModel.swift
//  Haishin
//
//  Created by Claude on 29.01.26.
//

import Foundation


//#################################################################################
// MARK: - SourceDetailViewModel
//#################################################################################

/// ViewModel for the source detail screen displaying videos from a source.
@Observable
@MainActor
final class SourceDetailViewModel {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    /// The installed source being displayed.
    let source: InstalledSource

    /// Videos from this source.
    private(set) var videos: [VideoPreview] = []

    /// Whether videos are loading.
    private(set) var isLoading = false

    /// Error that occurred while loading videos.
    private(set) var error: Error?

    /// Whether content has been loaded at least once.
    private(set) var hasLoadedContent = false

    private let sourceManager: SourceManaging
    private let watchProgressService: WatchProgressServiceProtocol
    private let subscriptionService: SubscriptionServiceProtocol
    private let downloadService: DownloadServiceProtocol


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new source detail view model.
    /// - Parameters:
    ///   - source: The installed source to display.
    ///   - sourceManager: The source manager to use.
    ///   - watchProgressService: The service for accessing watch progress.
    ///   - subscriptionService: The service for managing subscriptions.
    ///   - downloadService: The service for managing downloads.
    init(source: InstalledSource,
         sourceManager: SourceManaging,
         watchProgressService: WatchProgressServiceProtocol,
         subscriptionService: SubscriptionServiceProtocol,
         downloadService: DownloadServiceProtocol) {
        self.source = source
        self.sourceManager = sourceManager
        self.watchProgressService = watchProgressService
        self.subscriptionService = subscriptionService
        self.downloadService = downloadService
    }


    //#################################################################################
    // MARK: - Public Methods
    //#################################################################################

    /// Loads videos from the source if not already loaded.
    /// - Parameter forceRefresh: If true, reloads content even if already loaded.
    func loadContent(forceRefresh: Bool = false) async {
        guard forceRefresh || !hasLoadedContent else { return }

        isLoading = true
        error = nil

        do {
            let loadedVideos = try await sourceManager.getEntryVideos(sourceId: source.id, page: 1)
            videos = loadedVideos
        } catch {
            self.error = error
            Log.error(.sources, "Failed to load videos: \(error)")
        }

        isLoading = false
        hasLoadedContent = true
    }


    //#################################################################################
    // MARK: - Child ViewModel Factory Methods
    //#################################################################################

    /// Creates an EpisodeListViewModel for the given video preview.
    /// - Parameter videoPreview: The video preview to show episodes for.
    /// - Returns: A new `EpisodeListViewModel` for the video.
    func makeEpisodeListViewModel(for videoPreview: VideoPreview) -> EpisodeListViewModel {
        EpisodeListViewModel(mode: .online(video: videoPreview),
                             sourceManager: sourceManager,
                             watchProgressService: watchProgressService,
                             subscriptionService: subscriptionService,
                             downloadService: downloadService)
    }
}
