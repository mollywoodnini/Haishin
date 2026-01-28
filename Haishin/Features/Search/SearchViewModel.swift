//
//  SearchViewModel.swift
//  Haishin
//
//  Created by Tan Nghia La on 24.01.26.
//

import Foundation


//#################################################################################
// MARK: - SourceSearchState
//#################################################################################

/// Represents the search state for a single source.
@Observable
final class SourceSearchState: Identifiable {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    /// The source ID.
    let sourceId: String

    /// The source name.
    let sourceName: String

    /// Whether this source is currently loading.
    private(set) var isLoading: Bool = true

    /// The search results from this source.
    private(set) var results: [VideoPreview] = []

    /// Error that occurred during search, if any.
    private(set) var error: Error?

    var id: String { sourceId }


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new source search state.
    /// - Parameters:
    ///   - sourceId: The source ID.
    ///   - sourceName: The source name.
    init(sourceId: String, sourceName: String) {
        self.sourceId = sourceId
        self.sourceName = sourceName
    }


    //#################################################################################
    // MARK: - Methods
    //#################################################################################

    /// Updates the state with search results.
    /// - Parameter results: The search results.
    @MainActor
    func setResults(_ results: [VideoPreview]) {
        self.results = results
        self.isLoading = false
        self.error = nil
    }

    /// Updates the state with an error.
    /// - Parameter error: The error that occurred.
    @MainActor
    func setError(_ error: Error) {
        self.error = error
        self.isLoading = false
        self.results = []
    }

    /// Resets to loading state.
    @MainActor
    func setLoading() {
        self.isLoading = true
        self.results = []
        self.error = nil
    }
}


//#################################################################################
// MARK: - SearchViewModel
//#################################################################################

/// ViewModel for the search screen.
@Observable
final class SearchViewModel {

    //#################################################################################
    // MARK: - Constants
    //#################################################################################

    private struct Constants {
        static let maxRecentSearches = 10
        static let recentSearchesKey = "recentSearches"
    }


    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    /// Search states for each source (shown immediately, load independently).
    private(set) var sourceStates: [SourceSearchState] = []

    /// The last error that occurred.
    private(set) var error: Error?

    /// Recent search queries.
    private(set) var recentSearches: [String] = []

    /// Whether there are any results across all sources.
    var hasResults: Bool {
        sourceStates.contains { !$0.results.isEmpty }
    }

    /// Whether any source is still loading.
    var isSearching: Bool {
        sourceStates.contains { $0.isLoading }
    }

    private let sourceManager: SourceManaging
    private let watchProgressService: WatchProgressServiceProtocol
    private let subscriptionService: SubscriptionServiceProtocol
    private let downloadService: DownloadServiceProtocol
    private let debounceMilliseconds: Int
    private var searchTask: Task<Void, Never>?
    private var lastSearchedQuery: String?


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new search view model.
    /// - Parameters:
    ///   - sourceManager: The source manager to use.
    ///   - watchProgressService: The service for accessing watch progress.
    ///   - subscriptionService: The service for managing subscriptions.
    ///   - downloadService: The service for managing downloads.
    ///   - debounceMilliseconds: The debounce delay in milliseconds (default 300).
    init(sourceManager: SourceManaging,
         watchProgressService: WatchProgressServiceProtocol,
         subscriptionService: SubscriptionServiceProtocol,
         downloadService: DownloadServiceProtocol,
         debounceMilliseconds: Int = 300) {
        self.sourceManager = sourceManager
        self.watchProgressService = watchProgressService
        self.subscriptionService = subscriptionService
        self.downloadService = downloadService
        self.debounceMilliseconds = debounceMilliseconds
        self.recentSearches = UserDefaults.standard.stringArray(forKey: Constants.recentSearchesKey) ?? []
    }


    //#################################################################################
    // MARK: - Public Methods
    //#################################################################################

    /// Searches for videos matching the query.
    /// - Parameter query: The search query.
    @MainActor
    func search(query: String) {
        Log.debug(.sources, "search() called with query: '\(query)'")
        
        // Cancel any existing search
        searchTask?.cancel()

        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            sourceStates = []
            lastSearchedQuery = nil
            return
        }

        // Debounce search
        searchTask = Task {
            if debounceMilliseconds > 0 {
                try? await Task.sleep(for: .milliseconds(debounceMilliseconds))
            }

            guard !Task.isCancelled else { return }

            await performSearch(query: query)
        }
    }

    /// Creates an EpisodeListViewModel for the given video preview.
    /// - Parameter videoPreview: The video preview to show episodes for.
    /// - Returns: A new `EpisodeListViewModel` for the video.
    @MainActor
    func makeEpisodeListViewModel(for videoPreview: VideoPreview) -> EpisodeListViewModel {
        EpisodeListViewModel(mode: .online(video: videoPreview, detailsURL: videoPreview.detailsURL),
                             sourceManager: sourceManager,
                             watchProgressService: watchProgressService,
                             subscriptionService: subscriptionService,
                             downloadService: downloadService)
    }

    /// Adds a query to recent searches.
    /// - Parameter query: The search query to add.
    func addToRecentSearches(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Remove if already exists to move to top
        recentSearches.removeAll { $0.lowercased() == trimmed.lowercased() }

        // Insert at the beginning
        recentSearches.insert(trimmed, at: 0)

        // Limit to max count
        if recentSearches.count > Constants.maxRecentSearches {
            recentSearches = Array(recentSearches.prefix(Constants.maxRecentSearches))
        }

        // Persist
        UserDefaults.standard.set(recentSearches, forKey: Constants.recentSearchesKey)
    }

    /// Removes a query from recent searches.
    /// - Parameter query: The search query to remove.
    func removeFromRecentSearches(_ query: String) {
        recentSearches.removeAll { $0 == query }
        UserDefaults.standard.set(recentSearches, forKey: Constants.recentSearchesKey)
    }

    /// Clears all recent searches.
    func clearRecentSearches() {
        recentSearches.removeAll()
        UserDefaults.standard.removeObject(forKey: Constants.recentSearchesKey)
    }


    //#################################################################################
    // MARK: - Private Methods
    //#################################################################################

    @MainActor
    private func performSearch(query: String) async {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        // Prevent duplicate searches for the same query
        guard trimmedQuery != lastSearchedQuery else {
            Log.debug(.sources, "performSearch() skipped - same query: '\(trimmedQuery)'")
            return
        }
        lastSearchedQuery = trimmedQuery
        
        // Add to recent searches
        addToRecentSearches(trimmedQuery)
        
        Log.debug(.sources, "performSearch() executing for query: '\(trimmedQuery)'")

        let installedSources = sourceManager.installedSources
        Log.debug(.sources, "Found \(installedSources.count) installed sources")

        // Immediately create states for all sources (sorted by name)
        let sortedSources = installedSources.sorted { $0.info.name < $1.info.name }
        sourceStates = sortedSources.map { source in
            SourceSearchState(sourceId: source.id, sourceName: source.info.name)
        }

        // Launch independent search tasks for each source
        for state in sourceStates {
            Task { @MainActor in
                do {
                    Log.debug(.sources, "Searching source '\(state.sourceName)' for: '\(query)'")

                    let results = try await sourceManager.search(sourceId: state.sourceId,
                                                                 query: query,
                                                                 page: 1)
                    state.setResults(results)
                } catch {
                    Log.error(.sources, "Search failed for \(state.sourceId): \(error)")
                    state.setError(error)
                }
            }
        }
    }
}
