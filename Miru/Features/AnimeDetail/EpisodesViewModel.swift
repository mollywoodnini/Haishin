//
//  EpisodesViewModel.swift
//  Miru
//
//  Created by Miru on 24.01.26.
//

import Foundation

/// ViewModel for managing episode fetching from JavaScript sources.
@Observable
@MainActor
final class EpisodesViewModel {

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

    private let sourceManager: SourceManaging


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new episodes view model.
    /// - Parameters:
    ///   - aniListAnime: The AniList anime details.
    ///   - sourceId: The selected source ID.
    ///   - sourceManager: The source manager for fetching episodes.
    init(aniListAnime: AniListAnimeDetail,
         sourceId: String,
         sourceManager: SourceManaging) {
        print("[EpisodesViewModel] init called for anime: '\(aniListAnime.title)', sourceId: '\(sourceId)'")
        self.aniListAnime = aniListAnime
        self.sourceId = sourceId
        self.sourceManager = sourceManager
        print("[EpisodesViewModel] init complete. SourceManager has \(sourceManager.installedSources.count) sources")
    }

    /// Convenience initializer with default source manager.
    convenience init(aniListAnime: AniListAnimeDetail,
                     sourceId: String) {
        // Note: This will create a new SourceManager which won't have loaded sources.
        // The view should inject the shared SourceManager from the environment.
        self.init(aniListAnime: aniListAnime,
                  sourceId: sourceId,
                  sourceManager: SourceManager())
    }


    //#################################################################################
    // MARK: - Public Methods
    //#################################################################################

    /// Loads episodes by searching the source for the anime.
    func loadEpisodes() async {
        isLoading = true
        error = nil
        
        print("[EpisodesViewModel] Loading episodes for '\(aniListAnime.title)' from source '\(sourceId)'")
        print("[EpisodesViewModel] SourceManager installed sources: \(sourceManager.installedSources.count)")

        do {
            // Search for the anime on the selected source
            print("[EpisodesViewModel] Searching for anime...")
            let searchResults = try await sourceManager.search(sourceId: sourceId,
                                                               query: aniListAnime.title,
                                                               page: 1)
            
            print("[EpisodesViewModel] Search returned \(searchResults.count) results")

            // Find the best match (for now, take the first result)
            // TODO: Implement fuzzy matching or let user select
            guard let firstResult = searchResults.first else {
                print("[EpisodesViewModel] No search results found")
                error = EpisodesError.animeNotFound
                isLoading = false
                return
            }
            
            print("[EpisodesViewModel] Using first result: '\(firstResult.title)'")

            // Fetch full anime details with episodes
            print("[EpisodesViewModel] Fetching anime details...")
            let anime = try await sourceManager.getAnimeDetails(sourceId: sourceId,
                                                                url: firstResult.detailsURL)
            print("[EpisodesViewModel] Got anime with \(anime.episodes.count) episodes")
            sourceAnime = anime
            isLoading = false
        } catch {
            print("[EpisodesViewModel] Error loading episodes: \(error)")
            self.error = error
            isLoading = false
        }
    }

    /// Retries loading episodes.
    func retry() async {
        await loadEpisodes()
    }
}


//#################################################################################
// MARK: - EpisodesError
//#################################################################################

enum EpisodesError: LocalizedError {
    case animeNotFound

    var errorDescription: String? {
        switch self {
        case .animeNotFound:
            return "Could not find this anime on the selected source."
        }
    }
}
