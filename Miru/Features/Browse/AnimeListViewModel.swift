//
//  AnimeListViewModel.swift
//  Miru
//
//  Created by Miru on 24.01.26.
//

import Foundation


//#################################################################################
// MARK: - AnimeListViewModel
//#################################################################################

/// ViewModel for the anime list screen with infinite scroll pagination.
@Observable
final class AnimeListViewModel {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    /// The title of the list.
    let title: String

    /// The type of anime list being displayed.
    let listType: AnimeListType

    /// All loaded anime items.
    private(set) var items: [RecommendingItem] = []

    /// Whether the initial load is in progress.
    private(set) var isLoading = false

    /// Whether more content is being loaded.
    private(set) var isLoadingMore = false

    /// Whether there are more pages available.
    private(set) var hasMorePages = true

    /// The last error that occurred.
    private(set) var error: Error?

    private let aniListService: AniListServicing
    private var currentPage = 0


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new anime list view model.
    /// - Parameters:
    ///   - title: The title of the list.
    ///   - listType: The type of anime list to display.
    ///   - aniListService: The AniList service for fetching anime.
    init(
        title: String,
        listType: AnimeListType,
        aniListService: AniListServicing = AniListService()
    ) {
        self.title = title
        self.listType = listType
        self.aniListService = aniListService
    }


    //#################################################################################
    // MARK: - Public Methods
    //#################################################################################

    /// Loads the initial content.
    func loadInitialContent() async {
        guard !isLoading && items.isEmpty else { return }

        isLoading = true
        error = nil
        currentPage = 1

        do {
            let response = try await fetchPage(currentPage)
            await MainActor.run {
                items = response.items
                hasMorePages = response.hasNextPage
                isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = error
                isLoading = false
            }
        }
    }

    /// Loads more content when reaching the end of the list.
    func loadMoreIfNeeded(currentItem: RecommendingItem) async {
        // Check if we're near the end of the list (last 5 items)
        guard let index = items.firstIndex(of: currentItem),
              index >= items.count - 5 else {
            return
        }

        await loadMore()
    }

    /// Loads the next page of content.
    func loadMore() async {
        guard !isLoadingMore && !isLoading && hasMorePages else { return }

        isLoadingMore = true

        do {
            let nextPage = currentPage + 1
            let response = try await fetchPage(nextPage)
            await MainActor.run {
                items.append(contentsOf: response.items)
                currentPage = nextPage
                hasMorePages = response.hasNextPage
                isLoadingMore = false
            }
        } catch {
            await MainActor.run {
                self.error = error
                isLoadingMore = false
            }
        }
    }

    /// Refreshes all content.
    func refresh() async {
        items = []
        currentPage = 0
        hasMorePages = true
        error = nil
        await loadInitialContent()
    }


    //#################################################################################
    // MARK: - Private Methods
    //#################################################################################

    private func fetchPage(_ page: Int) async throws -> PaginatedResponse {
        switch listType {
        case .trending:
            return try await aniListService.fetchTrending(page: page)
        case .seasonal:
            return try await aniListService.fetchSeasonal(page: page)
        }
    }
}
