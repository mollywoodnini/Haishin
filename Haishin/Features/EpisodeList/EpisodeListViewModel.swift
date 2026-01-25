//
//  EpisodeListViewModel.swift
//  Miru
//
//  Created by Miru on 24.01.26.
//

import Foundation

/// ViewModel for managing episode fetching from JavaScript sources.
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
        print("[EpisodeListViewModel] init called for anime: '\(aniListAnime.title)', sourceId: '\(sourceId)'")
        self.aniListAnime = aniListAnime
        self.sourceId = sourceId
        self.sourceManager = sourceManager
        print("[EpisodeListViewModel] init complete. SourceManager has \(sourceManager.installedSources.count) sources")
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
        
        print("[EpisodeListViewModel] Loading episodes for '\(aniListAnime.title)' from source '\(sourceId)'")
        print("[EpisodeListViewModel] SourceManager installed sources: \(sourceManager.installedSources.count)")
        
        // Log all installed source IDs for debugging
        let installedIds = sourceManager.installedSources.map { $0.id }.joined(separator: ", ")
        print("[EpisodeListViewModel] Installed source IDs: [\(installedIds)]")
        
        // Validate that the selected source exists
        guard sourceManager.installedSources.contains(where: { $0.id == sourceId }) else {
            print("[EpisodeListViewModel] ERROR: Selected source '\(sourceId)' not found in installed sources")
            error = EpisodesError.sourceNotFoundHint
            isLoading = false
            return
        }

        do {
            // Generate search queries with fallbacks
            let searchQueries = generateSearchQueries()
            print("[EpisodeListViewModel] Generated \(searchQueries.count) search queries: \(searchQueries)")
            
            // Try each query until we find results
            var searchResults: [AnimePreview] = []
            var successfulQuery: String?
            
            for query in searchQueries {
                print("[EpisodeListViewModel] Trying search query: '\(query)'")
                let results = try await sourceManager.search(sourceId: sourceId,
                                                             query: query,
                                                             page: 1)
                print("[EpisodeListViewModel] Search for '\(query)' returned \(results.count) results")
                
                if !results.isEmpty {
                    searchResults = results
                    successfulQuery = query
                    break
                }
            }

            // Check if we found any results
            guard let firstResult = searchResults.first else {
                print("[EpisodeListViewModel] No search results found after trying all queries")
                error = EpisodesError.animeNotFound
                isLoading = false
                return
            }
            
            print("[EpisodeListViewModel] Found match with query '\(successfulQuery ?? "unknown")'")
            print("[EpisodeListViewModel] Using first result: '\(firstResult.title)'")

            // Fetch full anime details with episodes
            print("[EpisodeListViewModel] Fetching anime details...")
            let anime = try await sourceManager.getAnimeDetails(sourceId: sourceId,
                                                                url: firstResult.detailsURL)
            print("[EpisodeListViewModel] Got anime with \(anime.episodes.count) episodes")
            sourceAnime = anime
            isLoading = false
        } catch {
            print("[EpisodeListViewModel] Error loading episodes: \(error)")
            self.error = error
            isLoading = false
        }
    }

    /// Retries loading episodes.
    func retry() async {
        await loadEpisodes()
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
        // Example: "To Your Eternity Season 3" -> "To Your Eternity 3"
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
        // Example: "Attack on Titan Final Season Part 2" -> "Attack on Titan Final Season 2"
        let partVariation = removePartKeyword(from: aniListAnime.title)
        if partVariation != aniListAnime.title && !queries.contains(partVariation) {
            queries.append(partVariation)
        }
        
        return queries
    }
    
    /// Removes "Season X" and replaces with just "X".
    /// Example: "To Your Eternity Season 3" -> "To Your Eternity 3"
    private func removeSeasonKeyword(from title: String) -> String {
        // Pattern matches: "Season 3", "Season 2", etc.
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
    /// Example: "Attack on Titan Part 2" -> "Attack on Titan 2"
    private func removePartKeyword(from title: String) -> String {
        // Pattern matches: "Part 2", "Part 3", etc.
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
