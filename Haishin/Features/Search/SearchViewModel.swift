//
//  SearchViewModel.swift
//  Haishin
//
//  Created by Tan Nghia La on 24.01.26.
//

import Foundation


//#################################################################################
// MARK: - SearchViewModel
//#################################################################################

/// ViewModel for the search screen using the AniList API.
@Observable
@MainActor
final class SearchViewModel {

    //#################################################################################
    // MARK: - Constants
    //#################################################################################

    private enum Constants {
        static let maxRecentSearches = 10
        static let recentSearchesKey = "recentSearches"
    }


    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    /// The search results from AniList.
    private(set) var results: [RecommendingItem] = []

    /// Whether a search is currently in progress.
    private(set) var isSearching = false

    /// The last error that occurred.
    private(set) var error: Error?

    /// Recent search queries.
    private(set) var recentSearches: [String] = []

    private let aniListService: AniListServicing
    private let debounceMilliseconds: Int
    private var searchTask: Task<Void, Never>?
    private var lastSearchedQuery: String?


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new search view model.
    /// - Parameters:
    ///   - aniListService: The AniList service to use for searching.
    ///   - debounceMilliseconds: The debounce delay in milliseconds (default 300).
    init(aniListService: AniListServicing,
         debounceMilliseconds: Int = 300) {
        self.aniListService = aniListService
        self.debounceMilliseconds = debounceMilliseconds
        self.recentSearches = UserDefaults.standard.stringArray(forKey: Constants.recentSearchesKey) ?? []
    }


    //#################################################################################
    // MARK: - Public Methods
    //#################################################################################

    /// Searches for anime matching the query.
    /// - Parameter query: The search query.
    @MainActor
    func search(query: String) {
        // Cancel any existing search
        searchTask?.cancel()

        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            results = []
            error = nil
            isSearching = false
            lastSearchedQuery = nil
            return
        }

        isSearching = true

        // Debounce search
        searchTask = Task {
            if debounceMilliseconds > 0 {
                try? await Task.sleep(for: .milliseconds(debounceMilliseconds))
            }

            guard !Task.isCancelled else { return }

            await performSearch(query: query)
        }
    }

    /// Adds a query to recent searches.
    /// - Parameter query: The search query to add.
    func addToRecentSearches(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        recentSearches.removeAll { $0.lowercased() == trimmed.lowercased() }
        recentSearches.insert(trimmed, at: 0)

        if recentSearches.count > Constants.maxRecentSearches {
            recentSearches = Array(recentSearches.prefix(Constants.maxRecentSearches))
        }

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

        guard trimmedQuery != lastSearchedQuery else {
            return
        }
        lastSearchedQuery = trimmedQuery

        addToRecentSearches(trimmedQuery)

        do {
            let response = try await aniListService.search(query: trimmedQuery, page: 1, showNSFW: false)
            results = response.items
            error = nil
        } catch {
            self.error = error
            results = []
        }

        isSearching = false
    }
}
