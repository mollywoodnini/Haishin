//
//  EpisodeListViewModel.swift
//  Haishin
//
//  Created by Tan Nghia La on 24.01.26.
//

import Foundation


//#################################################################################
// MARK: - EpisodeListMode
//#################################################################################

/// The mode for displaying episodes with associated model data.
enum EpisodeListMode {
    /// Online mode - fetches episodes from a source.
    /// - Parameter video: The video to display.
    case online(video: any VideoProtocol)
    /// Offline mode - displays downloaded episodes.
    case offline(DownloadedVideo)

    /// Returns whether this is online mode.
    var isOnline: Bool {
        if case .online = self { return true }
        return false
    }

    /// Returns whether this is offline mode.
    var isOffline: Bool {
        if case .offline = self { return true }
        return false
    }
}


//#################################################################################
// MARK: - EpisodeListViewModel
//#################################################################################

/// ViewModel for managing episode fetching and playback state.
@Observable
@MainActor
final class EpisodeListViewModel: Identifiable, Hashable {

    //#################################################################################
    // MARK: - Identifiable & Hashable
    //#################################################################################

    nonisolated let id = UUID()

    nonisolated static func == (lhs: EpisodeListViewModel, rhs: EpisodeListViewModel) -> Bool {
        lhs.id == rhs.id
    }

    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }


    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    /// The display mode for the episode list.
    let mode: EpisodeListMode

    /// The matched video from the source (online mode).
    private(set) var sourceVideo: Video?

    /// Episodes converted from downloaded episodes (offline mode).
    private(set) var offlineEpisodes: [Episode] = []

    /// Whether data is currently loading.
    private(set) var isLoading = false

    /// The last error that occurred.
    private(set) var error: Error?

    /// Whether the user is subscribed to this video.
    private(set) var isSubscribed = false

    /// Watch progress for each episode, keyed by episode ID.
    private(set) var watchProgressMap: [String: WatchProgress] = [:]

    private let sourceManager: SourceManaging
    private let watchProgressService: WatchProgressServiceProtocol
    private let subscriptionService: SubscriptionServiceProtocol
    private let downloadService: DownloadServiceProtocol


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new episodes view model.
    /// - Parameters:
    ///   - mode: The display mode (online or offline) with associated data.
    ///   - sourceManager: The source manager for fetching episodes.
    ///   - watchProgressService: The service for accessing watch progress.
    ///   - subscriptionService: The service for managing subscriptions.
    ///   - downloadService: The service for managing downloads.
    init(mode: EpisodeListMode,
         sourceManager: SourceManaging,
         watchProgressService: WatchProgressServiceProtocol,
         subscriptionService: SubscriptionServiceProtocol,
         downloadService: DownloadServiceProtocol) {
        self.mode = mode
        self.sourceManager = sourceManager
        self.watchProgressService = watchProgressService
        self.subscriptionService = subscriptionService
        self.downloadService = downloadService

        switch mode {
        case .online(let video):
            self.isSubscribed = subscriptionService.isSubscribed(id: video.id)

        case .offline(let downloadedVideo):
            self.isSubscribed = subscriptionService.isSubscribed(id: downloadedVideo.id)
            self.offlineEpisodes = downloadedVideo.episodes
                .filter { $0.state.isCompleted }
                .sorted { $0.episodeNumber < $1.episodeNumber }
                .map { downloadedEpisode in
                    Episode(
                        id: downloadedEpisode.episodeId,
                        number: downloadedEpisode.episodeNumber,
                        title: downloadedEpisode.episodeTitle,
                        thumbnailURL: nil,
                        url: downloadedEpisode.localFilePath ?? downloadedEpisode.sourceURL,
                        duration: nil
                    )
                }
        }
    }
    

    //#################################################################################
    // MARK: - Public Computed Properties
    //#################################################################################

    /// The video ID.
    var videoId: String {
        switch mode {
        case .online(let video):
            return video.id
        case .offline(let downloadedVideo):
            return downloadedVideo.id
        }
    }

    /// The video title.
    var videoTitle: String {
        switch mode {
        case .online(let video):
            return video.title
        case .offline(let downloadedVideo):
            return downloadedVideo.title
        }
    }

    /// The video cover URL.
    var videoCoverURL: URL? {
        switch mode {
        case .online(let video):
            return video.coverURL
        case .offline(let downloadedVideo):
            return downloadedVideo.coverURL
        }
    }

    /// The source ID for this video.
    var sourceId: String {
        switch mode {
        case .online(let video):
            return video.sourceId
        case .offline(let downloadedVideo):
            return downloadedVideo.sourceId
        }
    }

    /// Returns the list of installed sources for the source picker.
    var installedSources: [InstalledSource] {
        sourceManager.installedSources
    }

    /// Returns the episodes to display based on mode.
    var episodes: [Episode] {
        switch mode {
        case .online:
            return sourceVideo?.episodes ?? []
        case .offline:
            return offlineEpisodes
        }
    }

    /// Returns the source name for display.
    var sourceName: String? {
        switch mode {
        case .online:
            return sourceManager.installedSources.first { $0.id == sourceId }?.info.name
        case .offline(let downloadedVideo):
            return downloadedVideo.sourceName
        }
    }

    /// Returns the direct details URL for the video.
    /// Prefers the URL from the loaded sourceVideo, falls back to the video's detailsURL.
    var detailsURL: String? {
        switch mode {
        case .online(let video):
            // Prefer the URL from the loaded sourceVideo, fall back to the video's URL
            return sourceVideo?.detailsURL ?? video.detailsURL
        case .offline(let downloadedVideo):
            return downloadedVideo.detailsURL
        }
    }


    //#################################################################################
    // MARK: - Public Methods
    //#################################################################################

    /// Loads episodes based on the current mode.
    func loadEpisodes() async {
        switch mode {
        case .online:
            await loadOnlineEpisodes()
        case .offline:
            loadOfflineEpisodes()
        }
    }

    /// Retries loading episodes.
    func retry() async {
        await loadEpisodes()
    }

    /// Reloads watch progress from the service.
    func loadWatchProgress() {
        let allProgress = watchProgressService.getAllProgress(videoId: videoId)
        var progressMap: [String: WatchProgress] = [:]
        for progress in allProgress {
            progressMap[progress.episodeId] = progress
        }
        watchProgressMap = progressMap
    }

    /// Toggles the subscription status for this video.
    func toggleSubscription() {
        if isSubscribed {
            subscriptionService.unsubscribe(id: videoId)
        } else {
            subscriptionService.subscribe(
                id: videoId,
                title: videoTitle,
                coverURL: videoCoverURL,
                sourceId: sourceId,
                detailsURL: detailsURL
            )
        }
        
        isSubscribed.toggle()
    }

    /// Returns the episode to continue watching, or nil if no progress exists.
    /// - Parameter episodes: The list of episodes to check.
    /// - Returns: The episode to continue watching, or nil.
    func getContinueWatchingEpisode(from episodes: [Episode]) -> Episode? {
        // Sort episodes by number to find the latest watched
        let sortedEpisodes = episodes.sorted { ep1, ep2 in
            (Int(ep1.number) ?? 0) < (Int(ep2.number) ?? 0)
        }

        // Find the last episode that has progress
        var lastWatchedIndex: Int?
        var lastWatchedProgress: WatchProgress?

        for (index, episode) in sortedEpisodes.enumerated() {
            if let progress = watchProgressMap[episode.id] {
                lastWatchedIndex = index
                lastWatchedProgress = progress
            }
        }

        // No progress at all - no continue watching button
        guard let lastIndex = lastWatchedIndex, let progress = lastWatchedProgress else {
            return nil
        }

        // If the last watched episode is completed (>= 90%), return the next episode
        if progress.isCompleted {
            let nextIndex = lastIndex + 1
            if nextIndex < sortedEpisodes.count {
                return sortedEpisodes[nextIndex]
            }
            // All episodes completed - no continue watching
            return nil
        }

        // Return the episode that's in progress
        return sortedEpisodes[lastIndex]
    }

    /// Gets the download state for a specific episode.
    /// - Parameter episodeId: The episode ID to check.
    /// - Returns: The download state, or nil if not downloading.
    func getDownloadState(for episodeId: String) -> DownloadState? {
        downloadService.getDownloadState(episodeId: episodeId)
    }

    /// Starts downloading an episode (online mode only).
    /// - Parameter episode: The episode to download.
    func startDownload(episode: Episode) {
        guard mode.isOnline,
              let sourceName else {
            return
        }

        downloadService.startDownload(
            videoId: videoId,
            videoTitle: videoTitle,
            videoCoverURL: videoCoverURL,
            videoDetailsURL: detailsURL,
            episodeId: episode.id,
            episodeNumber: episode.number,
            episodeTitle: episode.title,
            sourceId: sourceId,
            sourceName: sourceName,
            sourceURL: episode.url
        )
    }

    /// Cancels a download in progress.
    /// - Parameter episodeId: The episode ID to cancel.
    func cancelDownload(episodeId: String) {
        downloadService.cancelDownload(episodeId: episodeId)
    }

    /// Deletes a downloaded episode (offline mode only).
    /// - Parameter episodeId: The episode ID to delete.
    func deleteDownload(episodeId: String) {
        guard mode.isOffline else { return }
        downloadService.removeDownload(episodeId: episodeId)

        // Update local episodes list
        offlineEpisodes.removeAll { $0.id == episodeId }
    }

    /// Checks if the video has any remaining downloaded episodes.
    var hasDownloadedEpisodes: Bool {
        !offlineEpisodes.isEmpty
    }


    //#################################################################################
    // MARK: - Child ViewModel Factory Methods
    //#################################################################################

    /// Creates a VideoPlayerViewModel for the given episode.
    /// - Parameter episode: The episode to play.
    /// - Returns: A new `VideoPlayerViewModel` for the episode.
    func makeVideoPlayerViewModel(episode: Episode) -> VideoPlayerViewModel {
        VideoPlayerViewModel(
            episode: episode,
            videoId: videoId,
            videoTitle: videoTitle,
            videoCoverURL: videoCoverURL,
            detailsURL: detailsURL,
            sourceId: sourceId,
            sourceManager: sourceManager,
            watchProgressService: watchProgressService,
            isOfflineMode: mode.isOffline
        )
    }

    /// Returns the next episode after the given episode, if available.
    /// - Parameter currentEpisode: The current episode.
    /// - Returns: The next episode, or nil if there is no next episode.
    func getNextEpisode(after currentEpisode: Episode) -> Episode? {
        let sortedEpisodes = episodes.sorted { $0.number < $1.number }

        guard let currentIndex = sortedEpisodes.firstIndex(where: { $0.id == currentEpisode.id }),
              currentIndex + 1 < sortedEpisodes.count else {
            return nil
        }

        return sortedEpisodes[currentIndex + 1]
    }


    //#################################################################################
    // MARK: - Private Methods
    //#################################################################################

    private func loadOnlineEpisodes() async {
        // Extract video from mode
        guard case .online(let video) = mode else { return }

        // Skip if already loaded
        guard sourceVideo == nil else {
            // Just reload watch progress in case it changed
            loadWatchProgress()
            return
        }

        isLoading = true
        error = nil

        // Validate that the selected source exists
        guard sourceManager.installedSources.contains(where: { $0.id == sourceId }) else {
            error = EpisodesError.sourceNotFoundHint
            isLoading = false
            return
        }

        do {
            let detailsURL: String
            
            // If we have a direct details URL from the video, use it
            if let directURL = video.detailsURL {
                detailsURL = directURL
            } else {
                // Generate search queries with fallbacks
                let searchQueries = generateSearchQueries()

                // Try each query until we find results
                var searchResults: [VideoPreview] = []
                var bestQuery = ""

                for query in searchQueries {
                    let results = try await sourceManager.search(
                        sourceId: sourceId,
                        query: query,
                        page: 1
                    )

                    if !results.isEmpty {
                        searchResults = results
                        bestQuery = query
                        break
                    }
                }

                // Find the best matching result using title similarity
                guard let bestMatch = findBestMatch(in: searchResults, for: bestQuery),
                      let matchDetailsURL = bestMatch.detailsURL else {
                    error = EpisodesError.videoNotFound
                    isLoading = false
                    return
                }
                
                detailsURL = matchDetailsURL
            }

            // Fetch full video details with episodes
            let loadedVideo = try await sourceManager.getVideoDetails(
                sourceId: sourceId,
                url: detailsURL
            )
            sourceVideo = loadedVideo
            loadWatchProgress()
            isLoading = false
        } catch {
            self.error = error
            isLoading = false
        }
    }

    private func loadOfflineEpisodes() {
        // Refresh from download service in case of updates
        if let currentDownloadedVideo = downloadService.downloadedVideo.first(where: { $0.id == videoId }) {
            offlineEpisodes = currentDownloadedVideo.episodes
                .filter { $0.state.isCompleted }
                .sorted { $0.episodeNumber < $1.episodeNumber }
                .map { downloadedEpisode in
                    Episode(
                        id: downloadedEpisode.episodeId,
                        number: downloadedEpisode.episodeNumber,
                        title: downloadedEpisode.episodeTitle,
                        thumbnailURL: nil,
                        url: downloadedEpisode.localFilePath ?? downloadedEpisode.sourceURL,
                        duration: nil
                    )
                }
        }
        loadWatchProgress()
    }

    /// Generates a list of search queries to try, with fallback strategies.
    /// - Returns: Array of search query strings ordered by priority.
    private func generateSearchQueries() -> [String] {
        var queries: [String] = []
        
        // Use the stored videoTitle
        queries.append(videoTitle)

        // Try season and part variations on the title
        let seasonVariation = removeSeasonKeyword(from: videoTitle)
        if seasonVariation != videoTitle {
            queries.append(seasonVariation)
        }

        let partVariation = removePartKeyword(from: videoTitle)
        if partVariation != videoTitle && !queries.contains(partVariation) {
            queries.append(partVariation)
        }

        return queries
    }

    /// Removes "Season X" and replaces with just "X".
    private func removeSeasonKeyword(from title: String) -> String {
        let pattern = #"\s+Season\s+(\d+)"#
        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: .caseInsensitive
        ) else {
            return title
        }

        let range = NSRange(title.startIndex..<title.endIndex, in: title)
        let modifiedTitle = regex.stringByReplacingMatches(
            in: title,
            options: [],
            range: range,
            withTemplate: " $1"
        )
        return modifiedTitle
    }

    /// Removes "Part X" and replaces with just "X".
    private func removePartKeyword(from title: String) -> String {
        let pattern = #"\s+Part\s+(\d+)"#
        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: .caseInsensitive
        ) else {
            return title
        }

        let range = NSRange(title.startIndex..<title.endIndex, in: title)
        let modifiedTitle = regex.stringByReplacingMatches(
            in: title,
            options: [],
            range: range,
            withTemplate: " $1"
        )
        return modifiedTitle
    }

    /// Finds the best matching video from search results using title similarity.
    /// - Parameters:
    ///   - results: The search results to search through.
    ///   - query: The original search query.
    /// - Returns: The best matching VideoPreview, or nil if no results.
    private func findBestMatch(in results: [VideoPreview], for query: String) -> VideoPreview? {
        guard !results.isEmpty else { return nil }

        // If only one result, return it
        if results.count == 1 {
            return results.first
        }

        // Calculate similarity scores for each result
        let scoredResults = results.map { result -> (preview: VideoPreview, score: Double) in
            let score = query.similarityScore(to: result.title)
            return (result, score)
        }

        // Sort by score descending and return the best match
        let bestMatch = scoredResults.max { $0.score < $1.score }

        if let best = bestMatch {
            Log.debug(.sources, "Best match: '\(best.preview.title)' with score \(String(format: "%.2f", best.score))")
        }

        return bestMatch?.preview
    }
}


//#################################################################################
// MARK: - EpisodesError
//#################################################################################

enum EpisodesError: LocalizedError {
    case videoNotFound
    case sourceNotFoundHint

    var errorDescription: String? {
        switch self {
        case .videoNotFound:
            return "Could not find this video on the selected source."
        case .sourceNotFoundHint:
            return "The selected source is no longer installed. Please select a different source or reinstall it."
        }
    }
}
