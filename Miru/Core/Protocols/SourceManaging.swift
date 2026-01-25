//
//  SourceManaging.swift
//  Miru
//
//  Created by Miru on 24.01.26.
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

    /// Gets the popular anime from a source.
    /// - Parameters:
    ///   - sourceId: The source to query.
    ///   - page: Page number.
    /// - Returns: List of anime previews.
    func getPopular(sourceId: String, page: Int) async throws -> [AnimePreview]

    /// Gets the latest anime from a source.
    /// - Parameters:
    ///   - sourceId: The source to query.
    ///   - page: Page number.
    /// - Returns: List of anime previews.
    func getLatest(sourceId: String, page: Int) async throws -> [AnimePreview]

    /// Searches for anime in a source.
    /// - Parameters:
    ///   - sourceId: The source to search.
    ///   - query: Search query.
    ///   - page: Page number.
    /// - Returns: List of matching anime previews.
    func search(sourceId: String, query: String, page: Int) async throws -> [AnimePreview]

    /// Gets full anime details.
    /// - Parameters:
    ///   - sourceId: The source.
    ///   - url: The anime details URL.
    /// - Returns: Full anime information.
    func getAnimeDetails(sourceId: String, url: String) async throws -> Anime

    /// Gets video sources for an episode.
    /// - Parameters:
    ///   - sourceId: The source.
    ///   - url: The episode URL.
    /// - Returns: Playback information.
    func getVideoSources(sourceId: String, url: String) async throws -> PlaybackInfo
}
