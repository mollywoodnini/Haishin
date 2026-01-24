//
//  AniListServicing.swift
//  Miru
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
    /// - Returns: An array of recommending items for anime airing this week.
    func fetchThisWeek() async throws -> [RecommendingItem]

    /// Fetches trending anime.
    /// - Parameter page: The page number to fetch (1-indexed).
    /// - Returns: A paginated response containing trending anime.
    func fetchTrending(page: Int) async throws -> PaginatedResponse

    /// Fetches seasonal anime for the current season.
    /// - Parameter page: The page number to fetch (1-indexed).
    /// - Returns: A paginated response containing seasonal anime.
    func fetchSeasonal(page: Int) async throws -> PaginatedResponse
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
