//
//  EpisodeListViewModel.swift
//  Miru
//
//  Created by Miru on 24.01.26.
//

import Foundation


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

    /// The AniList anime details.
    let aniListAnime: AniListAnimeDetail

    /// The selected source ID.
    let sourceId: String

    /// The matched anime from the source.
    private(set) var sourceAnime: Anime?

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
        get { userPreferences.selectedSourceId }
        set { userPreferences.selectedSourceId = newValue }
    }

    private let sourceManager: SourceManaging
    private let watchProgressService: WatchProgressServiceProtocol
    private let subscriptionService: SubscriptionServiceProtocol
    private var userPreferences: UserPreferences


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new episodes view model.
    /// - Parameters:
    ///   - aniListAnime: The AniList anime details.
    ///   - sourceId: The selected source ID.
    ///   - sourceManager: The source manager for fetching episodes.
    ///   - watchProgressService: The service for accessing watch progress.
    ///   - subscriptionService: The service for managing subscriptions.
    ///   - userPreferences: The user preferences for source selection.
    init(aniListAnime: AniListAnimeDetail,
         sourceId: String,
         sourceManager: SourceManaging,
         watchProgressService: WatchProgressServiceProtocol,
         subscriptionService: SubscriptionServiceProtocol,
         userPreferences: UserPreferences) {
        self.aniListAnime = aniListAnime
        self.sourceId = sourceId
        self.sourceManager = sourceManager
        self.watchProgressService = watchProgressService
        self.subscriptionService = subscriptionService
        self.userPreferences = userPreferences
        self.isSubscribed = subscriptionService.isSubscribed(id: aniListAnime.id)
    }


    //#################################################################################
    // MARK: - Public Methods
    //#################################################################################

    /// Loads episodes by searching the source for the anime.
    func loadEpisodes() async {
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

    /// Retries loading episodes.
    func retry() async {
        await loadEpisodes()
    }

    /// Reloads watch progress from the service.
    func loadWatchProgress() {
        let allProgress = watchProgressService.getAllProgress(animeId: aniListAnime.id)
        var progressMap: [String: WatchProgress] = [:]
        for progress in allProgress {
            progressMap[progress.episodeId] = progress
        }
        watchProgressMap = progressMap
    }

    /// Toggles the subscription status for this anime.
    func toggleSubscription() {
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
        userPreferences.selectedSourceId = nil
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


    //#################################################################################
    // MARK: - Child ViewModel Factory Methods
    //#################################################################################

    /// Creates a VideoPlayerViewModel for the given episode.
    /// - Parameter episode: The episode to play.
    /// - Returns: A new `VideoPlayerViewModel` for the episode.
    func makeVideoPlayerViewModel(episode: Episode) -> VideoPlayerViewModel {
        VideoPlayerViewModel(episode: episode,
                             animeId: aniListAnime.id,
                             animeTitle: aniListAnime.title,
                             animeCoverURL: aniListAnime.coverURL,
                             sourceId: sourceId,
                             sourceManager: sourceManager,
                             watchProgressService: watchProgressService)
    }

    /// Returns the list of installed sources for the source picker.
    var installedSources: [InstalledSource] {
        sourceManager.installedSources
    }

    /// Returns the anime title for display in source picker.
    var animeTitle: String {
        aniListAnime.title
    }


    //#################################################################################
    // MARK: - Private Methods
    //#################################################################################

    /// Generates a list of search queries to try, with fallback strategies.
    /// - Returns: Array of search query strings ordered by priority.
    private func generateSearchQueries() -> [String] {
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
