//
//  AnimeDetailViewModel.swift
//  Haishin
//
//  Created by Haishin on 24.01.26.
//

import Foundation


//#################################################################################
// MARK: - AnimeDetailViewModel
//#################################################################################

/// ViewModel for displaying detailed anime information from AniList.
@Observable
@MainActor
final class AnimeDetailViewModel {


    //#################################################################################
    // MARK: - Types
    //#################################################################################

    /// The display mode with associated anime data.
    enum Mode {
        /// Display from a recommending item (e.g., from browse, search, or list).
        case item(RecommendingItem)
        /// Display from raw anime data (e.g., from relations or recommendations).
        case raw(animeId: Int, title: String, coverURL: URL?)
    }


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

    /// Whether the user is subscribed to this anime.
    private(set) var isSubscribed = false

    /// The currently selected source ID.
    var selectedSourceId: String? {
        get { userPreferences.selectedSourceId }
        set { userPreferences.selectedSourceId = newValue }
    }

    private let subscriptionService: SubscriptionServiceProtocol
    private let watchProgressService: WatchProgressServiceProtocol
    private let sourceManager: SourceManaging
    private let aniListService: AniListServicing
    private var userPreferences: UserPreferencesProtocol


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new view model.
    init(mode: Mode,
         aniListService: AniListServicing,
         subscriptionService: SubscriptionServiceProtocol,
         watchProgressService: WatchProgressServiceProtocol,
         sourceManager: SourceManaging,
         userPreferences: UserPreferencesProtocol) {
        switch mode {
        case .item(let item):
            self.animeId = item.anilistId
            self.previewTitle = item.title
            self.previewCoverURL = item.coverURL
        case .raw(let animeId, let title, let coverURL):
            self.animeId = animeId
            self.previewTitle = title
            self.previewCoverURL = coverURL
        }

        self.aniListService = aniListService
        self.subscriptionService = subscriptionService
        self.watchProgressService = watchProgressService
        self.sourceManager = sourceManager
        self.userPreferences = userPreferences
        self.isSubscribed = subscriptionService.isSubscribed(id: String(animeId))
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
        }

        isLoading = false
    }

    /// Retries loading the anime details after an error.
    func retry() async {
        error = nil
        anime = nil
        await loadDetails()
    }

    /// Toggles the subscription status for this anime.
    func toggleSubscription() {
        if isSubscribed {
            subscriptionService.unsubscribe(id: String(animeId))
        } else {
            subscriptionService.subscribe(
                id: String(animeId),
                title: displayTitle,
                coverURL: displayCoverURL,
                sourceId: "anilist",
                detailsURL: nil
            )
        }
        isSubscribed.toggle()
    }

    /// Validates the selected source and returns whether it's valid for navigation.
    func validateSourceSelection() -> Bool {
        guard let selectedId = selectedSourceId else {
            return false
        }

        let sourceExists = sourceManager.installedSources.contains { $0.id == selectedId }

        if !sourceExists {
            selectedSourceId = nil
        }

        return sourceExists
    }

    /// Clears the selected source.
    func clearSelectedSource() {
        selectedSourceId = nil
    }


    //#################################################################################
    // MARK: - Child ViewModel Factory Methods
    //#################################################################################

    /// Creates an EpisodeListViewModel for the loaded anime.
    func makeEpisodeListViewModel() -> EpisodeListViewModel? {
        guard let sourceId = selectedSourceId else {
            return nil
        }

        let video = AniListVideoAdapter(
            id: String(animeId),
            title: anime?.title ?? previewTitle,
            coverURL: anime?.coverURL ?? previewCoverURL,
            sourceId: sourceId,
            detailsURL: nil,
            alternativeTitles: anime?.alternativeSearchTitles ?? []
        )

        return EpisodeListViewModel(
            mode: .online(video: video),
            sourceManager: sourceManager,
            watchProgressService: watchProgressService,
            subscriptionService: subscriptionService,
            downloadService: DownloadService.shared
        )
    }

    /// Creates an AnimeDetailViewModel for a related anime.
    func makeRelatedAnimeDetailViewModel(relation: AniListRelation) -> AnimeDetailViewModel {
        AnimeDetailViewModel(
            mode: .raw(animeId: relation.id, title: relation.title, coverURL: relation.coverURL),
            aniListService: aniListService,
            subscriptionService: subscriptionService,
            watchProgressService: watchProgressService,
            sourceManager: sourceManager,
            userPreferences: userPreferences
        )
    }

    /// Creates an AnimeDetailViewModel for a recommended anime.
    func makeRecommendationDetailViewModel(recommendation: AniListRecommendation) -> AnimeDetailViewModel {
        AnimeDetailViewModel(
            mode: .raw(animeId: recommendation.id, title: recommendation.title, coverURL: recommendation.coverURL),
            aniListService: aniListService,
            subscriptionService: subscriptionService,
            watchProgressService: watchProgressService,
            sourceManager: sourceManager,
            userPreferences: userPreferences
        )
    }

    /// Returns the list of installed sources for the source picker.
    var installedSources: [InstalledSource] {
        sourceManager.installedSources
    }
}


//#################################################################################
// MARK: - AniListVideoAdapter
//#################################################################################

/// A VideoProtocol-conforming wrapper for AniList anime data.
/// A VideoProtocol-conforming wrapper for AniList anime data.
private struct AniListVideoAdapter: VideoProtocol {
    let id: String
    let title: String
    let coverURL: URL?
    let sourceId: String
    let detailsURL: String?
    let alternativeTitles: [String]
}


//#################################################################################
// MARK: - Computed Properties
//#################################################################################

extension AnimeDetailViewModel {

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
        guard let anime else { return nil }

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
        guard let anime else { return nil }

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

    /// The main characters.
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

    /// Information items for the Information section (key-value pairs).
    var informationItems: [(key: String, value: String)] {
        guard let anime else { return [] }

        var items: [(key: String, value: String)] = []

        if let format = anime.format {
            items.append((key: "Format", value: format.displayString))
        }

        items.append((key: "Airing Status", value: anime.status.displayString))

        if let startDate = anime.startDate?.formattedString {
            items.append((key: "Start Date", value: startDate))
        }

        if let endDate = anime.endDate?.formattedString {
            items.append((key: "End Date", value: endDate))
        }

        if let season = anime.season, let year = anime.seasonYear {
            items.append((key: "Season", value: "\(season.displayString) \(year)"))
        }

        if let episodes = anime.episodes {
            items.append((key: "Total Episodes", value: "\(episodes)"))
        }

        if let duration = anime.duration {
            items.append((key: "Episode Duration", value: "\(duration) min"))
        }

        if let country = anime.countryOfOrigin {
            items.append((key: "Origin Country", value: country))
        }

        if let source = anime.source {
            items.append((key: "Source", value: source))
        }

        if let studios = anime.studios.filter({ $0.isAnimationStudio }).map({ $0.name }).first {
            items.append((key: "Studio", value: studios))
        }

        return items
    }

    /// Formatted score for display in ratings section (0-100 scale as decimal).
    var formattedScore: String? {
        guard let score = anime?.averageScore else { return nil }
        let decimalScore = Double(score) / 10.0
        return String(format: "%.1f", decimalScore)
    }

    /// The popularity count formatted for display.
    var popularityString: String? {
        guard let popularity = anime?.popularity else { return nil }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: popularity))
    }

    /// The favorites count formatted for display.
    var favoritesString: String? {
        guard let favourites = anime?.favourites else { return nil }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: favourites))
    }
}
