//
//  SearchViewModel.swift
//  Haishin
//
//  Created by Haishin on 24.01.26.
//

import Foundation

/// ViewModel for the search screen.
@Observable
final class SearchViewModel {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    /// Search results.
    private(set) var results: [AnimePreview] = []

    /// Whether a search is in progress.
    private(set) var isSearching = false

    /// The last error that occurred.
    private(set) var error: Error?

    private let sourceManager: SourceManaging
    private let debounceMilliseconds: Int
    private var searchTask: Task<Void, Never>?


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new search view model.
    /// - Parameters:
    ///   - sourceManager: The source manager to use.
    ///   - debounceMilliseconds: The debounce delay in milliseconds (default 300).
    init(sourceManager: SourceManaging, debounceMilliseconds: Int = 300) {
        self.sourceManager = sourceManager
        self.debounceMilliseconds = debounceMilliseconds
    }


    //#################################################################################
    // MARK: - Public Methods
    //#################################################################################

    /// Searches for anime matching the query.
    /// - Parameter query: The search query.
    func search(query: String) async {
        // Cancel any existing search
        searchTask?.cancel()

        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            results = []
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
        
        // Wait for the search task to complete
        await searchTask?.value
    }

    /// Creates an EpisodeListViewModel for the given anime preview.
    /// - Parameter animePreview: The anime preview to show episodes for.
    /// - Returns: A new `EpisodeListViewModel` for the anime.
    @MainActor
    func makeEpisodeListViewModel(for animePreview: AnimePreview) -> EpisodeListViewModel {
        EpisodeListViewModel(animePreview: animePreview,
                             sourceManager: sourceManager,
                             watchProgressService: WatchProgressService.shared,
                             downloadService: DownloadService.shared)
    }


    //#################################################################################
    // MARK: - Private Methods
    //#################################################################################

    private func performSearch(query: String) async {
        isSearching = true
        defer { isSearching = false }

        var allResults: [AnimePreview] = []
        let enabledSources = sourceManager.installedSources.filter { $0.isEnabled }

        await withTaskGroup(of: [AnimePreview].self) { group in
            for source in enabledSources {
                let sourceId = source.id
                group.addTask {
                    do {
                        return try await self.sourceManager.search(sourceId: sourceId,
                                                                   query: query,
                                                                   page: 1)
                    } catch {
                        Log.error(.sources, "Search failed for \(sourceId): \(error)")
                        return []
                    }
                }
            }

            for await results in group {
                allResults.append(contentsOf: results)
            }
        }

        results = allResults
    }
}
