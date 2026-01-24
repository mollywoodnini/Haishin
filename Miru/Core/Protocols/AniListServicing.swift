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
    /// - Returns: An array of recommending items for trending anime.
    func fetchTrending() async throws -> [RecommendingItem]

    /// Fetches seasonal anime for the current season.
    /// - Returns: An array of recommending items for seasonal anime.
    func fetchSeasonal() async throws -> [RecommendingItem]
}
