//
//  EpisodeListViewModel.swift
//  Miru
//
//  Created by Miru on 24.01.26.
//

import Foundation


//#################################################################################
// MARK: - EpisodeListMode
//#################################################################################

/// The mode for displaying episodes.
enum EpisodeListMode {
    /// Online mode - fetches episodes from a source.
    case online
    /// Offline mode - displays downloaded episodes.
    case offline
}


//#################################################################################
// MARK: - EpisodeListViewModel
//#################################################################################

/// ViewModel for managing episode fetching and playback state.
@Observable
@MainActor
final class EpisodeListViewModel {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    /// The display mode for the episode list.
    let mode: EpisodeListMode

    /// The anime ID.
    let animeId: Int

    /// The anime title.
    let animeTitle: String

    /// The anime cover URL.
    let animeCoverURL: URL?

    /// The AniList anime details (only available in online mode).
    private let aniListAnime: AniListAnimeDetail?

    /// The downloaded anime (only available in offline mode).
    private let downloadedAnime: DownloadedAnime?

    /// The selected source ID.
    let sourceId: String?

    /// The matched anime from the source (online mode).
    private(set) var sourceAnime: Anime?

    /// Episodes converted from downloaded episodes (offline mode).
    private(set) var offlineEpisodes: [Episode] = []

    /// Whether data is currently loading.
    private(set) var isLoading = false

    /// The last error that occurred.
    private(set) var error: Error?

    /// Whether the user is subscribed to this anime.
    private(set) var isSubscribed = false

    /// Watch progress for each episode, keyed by episode ID.
    private(set) var watchProgressMap: [String: WatchProgress] = [:]

    /// The currently selected source ID from user preferences.
    var selectedSourceId: String? {
        get { userPreferences?.selectedSourceId }
        set { userPreferences?.selectedSourceId = newValue }
    }

    private let sourceManager: SourceManaging?
    private let watchProgressService: WatchProgressServiceProtocol
    private let subscriptionService: SubscriptionServiceProtocol?
    private let downloadService: DownloadServiceProtocol
    private var userPreferences: UserPreferences?


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new episodes view model for online mode.
    /// - Parameters:
    ///   - aniListAnime: The AniList anime details.
    ///   - sourceId: The selected source ID.
    ///   - sourceManager: The source manager for fetching episodes.
    ///   - watchProgressService: The service for accessing watch progress.
    ///   - subscriptionService: The service for managing subscriptions.
    ///   - downloadService: The service for managing downloads.
    ///   - userPreferences: The user preferences for source selection.
    init(aniListAnime: AniListAnimeDetail,
         sourceId: String,
         sourceManager: SourceManaging,
         watchProgressService: WatchProgressServiceProtocol,
         subscriptionService: SubscriptionServiceProtocol,
         downloadService: DownloadServiceProtocol = DownloadService.shared,
         userPreferences: UserPreferences) {
        self.mode = .online
        self.animeId = aniListAnime.id
        self.animeTitle = aniListAnime.title
        self.animeCoverURL = aniListAnime.coverURL
        self.aniListAnime = aniListAnime
        self.downloadedAnime = nil
        self.sourceId = sourceId
        self.sourceManager = sourceManager
        self.watchProgressService = watchProgressService
        self.subscriptionService = subscriptionService
        self.downloadService = downloadService
        self.userPreferences = userPreferences
        self.isSubscribed = subscriptionService.isSubscribed(id: aniListAnime.id)
    }

    /// Creates a new episodes view model for offline mode.
    /// - Parameters:
    ///   - downloadedAnime: The downloaded anime to display.
    ///   - watchProgressService: The service for accessing watch progress.
    ///   - downloadService: The service for managing downloads.
    init(downloadedAnime: DownloadedAnime,
         watchProgressService: WatchProgressServiceProtocol = WatchProgressService.shared,
         downloadService: DownloadServiceProtocol = DownloadService.shared) {
        self.mode = .offline
        self.animeId = downloadedAnime.id
        self.animeTitle = downloadedAnime.title
        self.animeCoverURL = downloadedAnime.coverURL
        self.aniListAnime = nil
        self.downloadedAnime = downloadedAnime
        self.sourceId = downloadedAnime.sourceId
        self.sourceManager = nil
        self.watchProgressService = watchProgressService
        self.subscriptionService = nil
        self.downloadService = downloadService
        self.userPreferences = nil
        self.isSubscribed = false

        // Convert downloaded episodes to Episode model
        self.offlineEpisodes = downloadedAnime.episodes
            .filter { $0.state.isCompleted }
            .sorted { ($0.episodeNumber) < ($1.episodeNumber) }
            .map { downloadedEpisode in
                Episode(id: downloadedEpisode.episodeId,
                        number: downloadedEpisode.episodeNumber,
                        title: downloadedEpisode.episodeTitle,
                        thumbnailURL: nil,
                        url: downloadedEpisode.localFilePath ?? downloadedEpisode.sourceURL,
                        duration: nil)
            }
    }


    //#################################################################################
    // MARK: - Public Computed Properties
    //#################################################################################

    /// Returns the list of installed sources for the source picker.
    var installedSources: [InstalledSource] {
        sourceManager?.installedSources ?? []
    }

    /// Returns the episodes to display based on mode.
    var episodes: [Episode] {
        switch mode {
        case .online:
            return sourceAnime?.episodes ?? []
        case .offline:
            return offlineEpisodes
        }
    }

    /// Returns the source name for display.
    var sourceName: String? {
        downloadedAnime?.sourceName
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
        let allProgress = watchProgressService.getAllProgress(animeId: animeId)
        var progressMap: [String: WatchProgress] = [:]
        for progress in allProgress {
            progressMap[progress.episodeId] = progress
        }
        watchProgressMap = progressMap
    }

    /// Toggles the subscription status for this anime.
    func toggleSubscription() {
        guard let aniListAnime, let subscriptionService else { return }

        if isSubscribed {
            subscriptionService.unsubscribe(id: aniListAnime.id)
        } else {
            subscriptionService.subscribe(id: aniListAnime.id,
                                          title: aniListAnime.title,
                                          coverURL: aniListAnime.coverURL)
        }
        isSubscribed.toggle()
    }

    /// Clears the selected source when it's invalid.
    func clearSelectedSource() {
        userPreferences?.selectedSourceId = nil
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
        guard mode == .online,
              let sourceId,
              let aniListAnime,
              let source = sourceManager?.installedSources.first(where: { $0.id == sourceId }) else {
            return
        }

        downloadService.startDownload(animeId: aniListAnime.id,
                                       animeTitle: aniListAnime.title,
                                       animeCoverURL: aniListAnime.coverURL,
                                       episodeId: episode.id,
                                       episodeNumber: episode.number,
                                       episodeTitle: episode.title,
                                       sourceId: sourceId,
                                       sourceName: source.info.name,
                                       sourceURL: episode.url)
    }

    /// Cancels a download in progress.
    /// - Parameter episodeId: The episode ID to cancel.
    func cancelDownload(episodeId: String) {
        downloadService.cancelDownload(episodeId: episodeId)
    }

    /// Deletes a downloaded episode (offline mode only).
    /// - Parameter episodeId: The episode ID to delete.
    func deleteDownload(episodeId: String) {
        guard mode == .offline else { return }
        downloadService.removeDownload(episodeId: episodeId)

        // Update local episodes list
        offlineEpisodes.removeAll { $0.id == episodeId }
    }

    /// Checks if the anime has any remaining downloaded episodes.
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
        VideoPlayerViewModel(episode: episode,
                             animeId: animeId,
                             animeTitle: animeTitle,
                             animeCoverURL: animeCoverURL,
                             sourceId: sourceId ?? "",
                             sourceManager: sourceManager,
                             watchProgressService: watchProgressService,
                             isOfflineMode: mode == .offline)
    }


    //#################################################################################
    // MARK: - Private Methods
    //#################################################################################

    private func loadOnlineEpisodes() async {
        guard let sourceManager, let sourceId else { return }

        isLoading = true
        error = nil

        // Validate that the selected source exists
        guard sourceManager.installedSources.contains(where: { $0.id == sourceId }) else {
            error = EpisodesError.sourceNotFoundHint
            isLoading = false
            return
        }

        do {
            // Generate search queries with fallbacks
            let searchQueries = generateSearchQueries()

            // Try each query until we find results
            var searchResults: [AnimePreview] = []

            for query in searchQueries {
                let results = try await sourceManager.search(sourceId: sourceId,
                                                             query: query,
                                                             page: 1)

                if !results.isEmpty {
                    searchResults = results
                    break
                }
            }

            // Check if we found any results
            guard let firstResult = searchResults.first else {
                error = EpisodesError.animeNotFound
                isLoading = false
                return
            }

            // Fetch full anime details with episodes
            let anime = try await sourceManager.getAnimeDetails(sourceId: sourceId,
                                                                url: firstResult.detailsURL)
            sourceAnime = anime
            loadWatchProgress()
            isLoading = false
        } catch {
            self.error = error
            isLoading = false
        }
    }

    private func loadOfflineEpisodes() {
        // Refresh from download service in case of updates
        if let currentDownloadedAnime = downloadService.downloadedAnime.first(where: { $0.id == animeId }) {
            offlineEpisodes = currentDownloadedAnime.episodes
                .filter { $0.state.isCompleted }
                .sorted { $0.episodeNumber < $1.episodeNumber }
                .map { downloadedEpisode in
                    Episode(id: downloadedEpisode.episodeId,
                            number: downloadedEpisode.episodeNumber,
                            title: downloadedEpisode.episodeTitle,
                            thumbnailURL: nil,
                            url: downloadedEpisode.localFilePath ?? downloadedEpisode.sourceURL,
                            duration: nil)
                }
        }
        loadWatchProgress()
    }

    /// Generates a list of search queries to try, with fallback strategies.
    /// - Returns: Array of search query strings ordered by priority.
    private func generateSearchQueries() -> [String] {
        guard let aniListAnime else { return [] }

        var queries: [String] = []

        // 1. Primary title (English or Romaji)
        queries.append(aniListAnime.title)

        // 2. Alternative titles (Romaji, Native, English)
        if let romaji = aniListAnime.romajiTitle, romaji != aniListAnime.title {
            queries.append(romaji)
        }

        if let english = aniListAnime.englishTitle, english != aniListAnime.title {
            queries.append(english)
        }

        if let native = aniListAnime.nativeTitle, native != aniListAnime.title {
            queries.append(native)
        }

        // 3. Remove "Season X" and replace with just the number
        let seasonVariation = removeSeasonKeyword(from: aniListAnime.title)
        if seasonVariation != aniListAnime.title {
            queries.append(seasonVariation)
        }

        // Try season variation on alternative titles too
        if let romaji = aniListAnime.romajiTitle {
            let romajiSeasonVariation = removeSeasonKeyword(from: romaji)
            if romajiSeasonVariation != romaji && !queries.contains(romajiSeasonVariation) {
                queries.append(romajiSeasonVariation)
            }
        }

        if let english = aniListAnime.englishTitle {
            let englishSeasonVariation = removeSeasonKeyword(from: english)
            if englishSeasonVariation != english && !queries.contains(englishSeasonVariation) {
                queries.append(englishSeasonVariation)
            }
        }

        // 4. Remove "Part X" variations
        let partVariation = removePartKeyword(from: aniListAnime.title)
        if partVariation != aniListAnime.title && !queries.contains(partVariation) {
            queries.append(partVariation)
        }

        return queries
    }

    /// Removes "Season X" and replaces with just "X".
    private func removeSeasonKeyword(from title: String) -> String {
        let pattern = #"\s+Season\s+(\d+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern,
                                                   options: .caseInsensitive) else {
            return title
        }

        let range = NSRange(title.startIndex..<title.endIndex, in: title)
        let modifiedTitle = regex.stringByReplacingMatches(in: title,
                                                           options: [],
                                                           range: range,
                                                           withTemplate: " $1")
        return modifiedTitle
    }

    /// Removes "Part X" and replaces with just "X".
    private func removePartKeyword(from title: String) -> String {
        let pattern = #"\s+Part\s+(\d+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern,
                                                   options: .caseInsensitive) else {
            return title
        }

        let range = NSRange(title.startIndex..<title.endIndex, in: title)
        let modifiedTitle = regex.stringByReplacingMatches(in: title,
                                                           options: [],
                                                           range: range,
                                                           withTemplate: " $1")
        return modifiedTitle
    }
}


//#################################################################################
// MARK: - EpisodesError
//#################################################################################

enum EpisodesError: LocalizedError {
    case animeNotFound
    case sourceNotFoundHint

    var errorDescription: String? {
        switch self {
        case .animeNotFound:
            return "Could not find this anime on the selected source."
        case .sourceNotFoundHint:
            return "The selected source is no longer installed. Please select a different source or reinstall it."
        }
    }
}
