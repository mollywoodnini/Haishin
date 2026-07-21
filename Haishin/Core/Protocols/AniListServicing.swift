//
//  AniListServicing.swift
//  Haishin
//
//  Created by Tan Nghia La on 24.01.26.
//

import Foundation


//#################################################################################
// MARK: - AniListServicing
//#################################################################################

/// Protocol for fetching anime data from AniList.
protocol AniListServicing: Sendable {

    /// Fetches the weekly airing schedule for the current week.
    /// - Parameter showNSFW: Whether to include NSFW (adult) content.
    /// - Returns: An array of recommending items for anime airing this week.
    func fetchThisWeek(showNSFW: Bool) async throws -> [RecommendingItem]

    /// Fetches trending anime.
    /// - Parameters:
    ///   - page: The page number to fetch (1-indexed).
    ///   - showNSFW: Whether to include NSFW (adult) content.
    /// - Returns: A paginated response containing trending anime.
    func fetchTrending(page: Int, showNSFW: Bool) async throws -> PaginatedResponse

    /// Fetches seasonal anime for the current season.
    /// - Parameters:
    ///   - page: The page number to fetch (1-indexed).
    ///   - showNSFW: Whether to include NSFW (adult) content.
    /// - Returns: A paginated response containing seasonal anime.
    func fetchSeasonal(page: Int, showNSFW: Bool) async throws -> PaginatedResponse

    /// Fetches detailed information for a specific anime.
    /// - Parameter id: The AniList ID of the anime.
    /// - Returns: Detailed anime information.
    func fetchAnimeDetails(id: Int) async throws -> AniListAnimeDetail

    /// Searches for anime matching the query.
    /// - Parameters:
    ///   - query: The search query.
    ///   - page: The page number (1-indexed).
    ///   - showNSFW: Whether to include NSFW content.
    /// - Returns: A paginated response containing matching anime.
    func search(query: String, page: Int, showNSFW: Bool) async throws -> PaginatedResponse
}


//#################################################################################
// MARK: - PaginatedResponse
//#################################################################################

/// A paginated response containing anime items and pagination info.
struct PaginatedResponse: Sendable {

    /// The items in this page.
    let items: [RecommendingItem]

    /// Whether there are more pages available.
    let hasNextPage: Bool

    /// The current page number.
    let currentPage: Int
}


//#################################################################################
// MARK: - AnimeListType
//#################################################################################

/// The type of anime list to display.
enum AnimeListType: Sendable {
    case trending
    case seasonal
}
