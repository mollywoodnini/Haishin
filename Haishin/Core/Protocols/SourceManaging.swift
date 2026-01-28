//
//  SourceManaging.swift
//  Haishin
//
//  Created by Tan Nghia La on 24.01.26.
//

import Foundation

/// Protocol defining the interface for source management.
/// This protocol enables dependency injection and testing.
protocol SourceManaging: AnyObject {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    /// Currently installed sources.
    var installedSources: [InstalledSource] { get }

    /// Available source repositories.
    var repositories: [SourceRepository] { get }

    /// Whether sources are currently being loaded.
    var isLoading: Bool { get }

    /// Last error that occurred.
    var lastError: Error? { get }


    //#################################################################################
    // MARK: - Methods
    //#################################################################################

    /// Loads all installed sources.
    func loadInstalledSources() async

    /// Adds a source repository.
    /// - Parameter url: URL to the repository manifest.
    func addRepository(url: URL) async throws

    /// Installs a source from a repository.
    /// - Parameters:
    ///   - source: The source info to install.
    ///   - repository: The repository containing the source.
    func installSource(_ source: SourceInfo, from repository: SourceRepository) async throws
    
    /// Installs a source from a URL string.
    /// - Parameter urlString: The URL to the source JavaScript file.
    func installSource(fromURL urlString: String) async throws

    /// Uninstalls a source.
    /// - Parameter sourceId: The source ID to uninstall.
    func uninstallSource(sourceId: String) throws

    /// Gets the popular videos from a source.
    /// - Parameters:
    ///   - sourceId: The source to query.
    ///   - page: Page number.
    /// - Returns: List of video previews.
    func getPopular(sourceId: String, page: Int) async throws -> [VideoPreview]

    /// Gets the latest videos from a source.
    /// - Parameters:
    ///   - sourceId: The source to query.
    ///   - page: Page number.
    /// - Returns: List of video previews.
    func getLatest(sourceId: String, page: Int) async throws -> [VideoPreview]

    /// Searches for videos in a source.
    /// - Parameters:
    ///   - sourceId: The source to search.
    ///   - query: Search query.
    ///   - page: Page number.
    /// - Returns: List of matching video previews.
    func search(sourceId: String, query: String, page: Int) async throws -> [VideoPreview]

    /// Gets full video details.
    /// - Parameters:
    ///   - sourceId: The source.
    ///   - url: The video details URL.
    /// - Returns: Full video information.
    func getVideoDetails(sourceId: String, url: String) async throws -> Video

    /// Gets video sources for an episode.
    /// - Parameters:
    ///   - sourceId: The source.
    ///   - episodeId: The episode identifier.
    ///   - url: The episode URL.
    /// - Returns: Playback information.
    func getVideoSources(sourceId: String, episodeId: String, url: String) async throws -> PlaybackInfo
}
