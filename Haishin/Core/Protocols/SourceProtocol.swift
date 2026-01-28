//
//  SourceProtocol.swift
//  Haishin
//
//  Created by Tan Nghia La on 24.01.26.
//

import Foundation

/// Protocol defining the interface for video sources.
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

    /// Fetches the popular/trending video list.
    /// - Parameter page: Page number for pagination (1-indexed).
    /// - Returns: A list of video previews.
    func getPopular(page: Int) async throws -> [VideoPreview]

    /// Fetches the latest updated videos.
    /// - Parameter page: Page number for pagination (1-indexed).
    /// - Returns: A list of video previews.
    func getLatest(page: Int) async throws -> [VideoPreview]

    /// Searches for videos by query.
    /// - Parameters:
    ///   - query: Search query string.
    ///   - page: Page number for pagination (1-indexed).
    /// - Returns: A list of matching video previews.
    func search(query: String, page: Int) async throws -> [VideoPreview]


    //#################################################################################
    // MARK: - Detail Methods
    //#################################################################################

    /// Fetches full video details including episodes.
    /// - Parameter url: The detail URL from a VideoPreview.
    /// - Returns: Complete video information.
    func getVideoDetails(url: String) async throws -> Video

    /// Fetches video sources for an episode.
    /// - Parameter url: The episode URL.
    /// - Returns: Playback information with available sources.
    func getVideoSources(url: String) async throws -> PlaybackInfo
}
