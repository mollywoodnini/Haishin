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
        self.aniListAnime = aniListAnime
        self.sourceId = sourceId
        self.sourceManager = sourceManager
    }

    /// Convenience initializer with default source manager.
    convenience init(aniListAnime: AniListAnimeDetail,
                     sourceId: String) {
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

        do {
            // Search for the anime on the selected source
            let searchResults = try await sourceManager.search(sourceId: sourceId,
                                                               query: aniListAnime.title,
                                                               page: 1)

            // Find the best match (for now, take the first result)
            // TODO: Implement fuzzy matching or let user select
            guard let firstResult = searchResults.first else {
                error = EpisodesError.animeNotFound
                isLoading = false
                return
            }

            // Fetch full anime details with episodes
            let anime = try await sourceManager.getAnimeDetails(sourceId: sourceId,
                                                                url: firstResult.detailsURL)
            sourceAnime = anime
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
