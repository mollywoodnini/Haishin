//
//  AniListAnimeDetailViewModel.swift
//  Miru
//
//  Created by Miru on 24.01.26.
//

import Foundation


//#################################################################################
// MARK: - AniListAnimeDetailViewModel
//#################################################################################

/// ViewModel for displaying detailed anime information from AniList.
@Observable
@MainActor
final class AniListAnimeDetailViewModel {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    /// The AniList ID of the anime to display.
    let animeId: Int

    /// The title to display while loading (from the recommendation item).
    let previewTitle: String

    /// The cover URL to display while loading.
    let previewCoverURL: URL?

    /// The loaded anime details.
    private(set) var anime: AniListAnimeDetail?

    /// Whether the details are currently being loaded.
    private(set) var isLoading = false

    /// The error that occurred during loading, if any.
    private(set) var error: Error?

    /// Whether the synopsis is expanded.
    var isSynopsisExpanded = false

    private let aniListService: AniListServicing


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new view model.
    /// - Parameters:
    ///   - animeId: The AniList ID of the anime.
    ///   - previewTitle: The title to display while loading.
    ///   - previewCoverURL: The cover URL to display while loading.
    ///   - aniListService: The service to fetch anime details.
    init(animeId: Int,
         previewTitle: String,
         previewCoverURL: URL?,
         aniListService: AniListServicing = AniListService()) {
        self.animeId = animeId
        self.previewTitle = previewTitle
        self.previewCoverURL = previewCoverURL
        self.aniListService = aniListService
    }

    /// Creates a new view model from a recommending item.
    /// - Parameters:
    ///   - item: The recommending item to display details for.
    ///   - aniListService: The service to fetch anime details.
    convenience init(item: RecommendingItem,
                     aniListService: AniListServicing = AniListService()) {
        self.init(animeId: item.anilistId,
                  previewTitle: item.title,
                  previewCoverURL: item.coverURL,
                  aniListService: aniListService)
    }


    //#################################################################################
    // MARK: - Public Methods
    //#################################################################################

    /// Loads the anime details.
    func loadDetails() async {
        guard anime == nil, !isLoading else { return }

        isLoading = true
        error = nil

        do {
            anime = try await aniListService.fetchAnimeDetails(id: animeId)
        } catch {
            self.error = error
            print("[AniListAnimeDetailViewModel] Failed to load details: \(error)")
        }

        isLoading = false
    }

    /// Retries loading the anime details after an error.
    func retry() async {
        error = nil
        anime = nil
        await loadDetails()
    }
}


//#################################################################################
// MARK: - Computed Properties
//#################################################################################

extension AniListAnimeDetailViewModel {

    /// The display title (loaded or preview).
    var displayTitle: String {
        anime?.title ?? previewTitle
    }

    /// The cover URL (loaded or preview).
    var displayCoverURL: URL? {
        anime?.coverURL ?? previewCoverURL
    }

    /// Alternative titles formatted for display.
    var alternativeTitles: String? {
        guard let anime = anime else { return nil }

        let titles = [anime.englishTitle, anime.romajiTitle, anime.nativeTitle]
            .compactMap { $0 }
            .filter { $0 != anime.title && !$0.isEmpty }

        return titles.isEmpty ? nil : titles.joined(separator: " • ")
    }

    /// The formatted score string.
    var scoreString: String? {
        guard let score = anime?.averageScore else { return nil }
        return "\(score)%"
    }

    /// The formatted episode count string.
    var episodeCountString: String? {
        guard let episodes = anime?.episodes else { return nil }
        if let duration = anime?.duration {
            return "\(episodes) episodes • \(duration) min"
        }
        return "\(episodes) episodes"
    }

    /// The formatted season and year string.
    var seasonYearString: String? {
        guard let anime = anime else { return nil }

        if let season = anime.season, let year = anime.seasonYear {
            return "\(season.displayString) \(year)"
        } else if let year = anime.seasonYear {
            return "\(year)"
        } else if let startDate = anime.startDate?.formattedString {
            return startDate
        }

        return nil
    }

    /// The studio names formatted for display.
    var studioString: String? {
        guard let studios = anime?.studios, !studios.isEmpty else { return nil }
        return studios.map(\.name).joined(separator: ", ")
    }

    /// The main characters (limited to avoid overwhelming the UI).
    var mainCharacters: [AniListCharacter] {
        anime?.characters.filter { $0.role == .main } ?? []
    }

    /// Supporting characters.
    var supportingCharacters: [AniListCharacter] {
        anime?.characters.filter { $0.role == .supporting } ?? []
    }

    /// Streaming links only.
    var streamingLinks: [AniListExternalLink] {
        anime?.externalLinks.filter { $0.type == .streaming } ?? []
    }

    /// Non-spoiler tags for display.
    var displayTags: [AniListTag] {
        anime?.tags.filter { !$0.isMediaSpoiler }.prefix(10).map { $0 } ?? []
    }
}
