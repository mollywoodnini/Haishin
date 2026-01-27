//
//  SourceProtocol.swift
//  Haishin
//
//  Created by Haishin on 24.01.26.
//

import Foundation

/// Protocol defining the interface for anime sources.
/// This is the contract that JavaScript sources must implement.
protocol SourceProtocol {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    /// Metadata about the source.
    var info: SourceInfo { get }


    //#################################################################################
    // MARK: - Discovery Methods
    //#################################################################################

    /// Fetches the popular/trending anime list.
    /// - Parameter page: Page number for pagination (1-indexed).
    /// - Returns: A list of anime previews.
    func getPopular(page: Int) async throws -> [AnimePreview]

    /// Fetches the latest updated anime.
    /// - Parameter page: Page number for pagination (1-indexed).
    /// - Returns: A list of anime previews.
    func getLatest(page: Int) async throws -> [AnimePreview]

    /// Searches for anime by query.
    /// - Parameters:
    ///   - query: Search query string.
    ///   - page: Page number for pagination (1-indexed).
    /// - Returns: A list of matching anime previews.
    func search(query: String, page: Int) async throws -> [AnimePreview]


    //#################################################################################
    // MARK: - Detail Methods
    //#################################################################################

    /// Fetches full anime details including episodes.
    /// - Parameter url: The detail URL from an AnimePreview.
    /// - Returns: Complete anime information.
    func getAnimeDetails(url: String) async throws -> Anime

    /// Fetches video sources for an episode.
    /// - Parameter url: The episode URL.
    /// - Returns: Playback information with available sources.
    func getVideoSources(url: String) async throws -> PlaybackInfo
}
