//
//  JavaScriptSource.swift
//  Miru
//
//  Created by Miru on 24.01.26.
//

import Foundation

/// Represents a JavaScript-based anime source.
/// Wraps a JavaScript source script and provides Swift-friendly async methods.
final actor JavaScriptSource {
    
    //#################################################################################
    // MARK: - Properties
    //#################################################################################
    
    /// Metadata about this source
    let info: SourceInfo
    
    /// Whether this source is currently enabled
    var isEnabled: Bool
    
    private let runtime: JSRuntime
    private let sourceId: String
    
    
    //#################################################################################
    // MARK: - Initialization
    //#################################################################################
    
    /// Creates a new JavaScript source from a script.
    /// - Parameters:
    ///   - script: The JavaScript source code to load.
    ///   - sourceId: Unique identifier for this source.
    ///   - runtime: The JavaScript runtime to use.
    init(script: String,
         sourceId: String,
         runtime: JSRuntime) async throws {
        self.runtime = runtime
        self.sourceId = sourceId
        self.isEnabled = true
        
        // Load the script into the runtime
        try await runtime.loadSource(script: script, sourceId: sourceId)
        
        // Extract metadata
        self.info = try await runtime.getSourceInfo(sourceId: sourceId)
    }
    
    
    //#################################################################################
    // MARK: - Public Methods
    //#################################################################################
    
    /// Searches for anime matching the query.
    /// - Parameters:
    ///   - query: The search query.
    ///   - page: The page number (1-indexed).
    /// - Returns: Search results with anime previews.
    func search(query: String, page: Int = 1) async throws -> JSSearchResult {
        let jsonString = try await runtime.callAsyncFunction(sourceId: sourceId,
                                                              functionName: "source.search",
                                                              arguments: [query, page])
        
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw JSRuntime.JSError.invalidResult("Invalid UTF-8 in search result")
        }
        
        return try JSONDecoder().decode(JSSearchResult.self, from: jsonData)
    }
    
    /// Gets detailed information about an anime.
    /// - Parameters:
    ///   - animeId: The anime's unique identifier.
    ///   - animeUrl: Full URL to the anime's page on the source website.
    /// - Returns: Detailed anime information including episodes.
    func getAnimeDetails(animeId: String, animeUrl: URL) async throws -> JSAnimeDetails {
        let jsonString = try await runtime.callAsyncFunction(sourceId: sourceId,
                                                              functionName: "source.getAnimeDetails",
                                                              arguments: [animeId, animeUrl.absoluteString])
        
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw JSRuntime.JSError.invalidResult("Invalid UTF-8 in anime details result")
        }
        
        return try JSONDecoder().decode(JSAnimeDetails.self, from: jsonData)
    }
    
    /// Gets streaming information for an episode.
    /// - Parameters:
    ///   - episodeId: The episode's unique identifier.
    ///   - episodeUrl: Full URL to the episode page.
    ///   - server: The server/provider identifier to use.
    /// - Returns: Streaming URLs and subtitle information.
    func getEpisodeStreams(episodeId: String,
                           episodeUrl: URL,
                           server: String) async throws -> JSEpisodeStream {
        let jsonString = try await runtime.callAsyncFunction(sourceId: sourceId,
                                                              functionName: "source.getEpisodeStreams",
                                                              arguments: [episodeId, episodeUrl.absoluteString, server])
        
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw JSRuntime.JSError.invalidResult("Invalid UTF-8 in episode streams result")
        }
        
        return try JSONDecoder().decode(JSEpisodeStream.self, from: jsonData)
    }
    
    /// Gets featured/popular anime from the source.
    /// - Returns: Array of featured anime previews.
    func getFeatured() async throws -> [JSAnimePreview] {
        let jsonString = try await runtime.callAsyncFunction(sourceId: sourceId,
                                                              functionName: "source.getFeatured",
                                                              arguments: [])
        
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw JSRuntime.JSError.invalidResult("Invalid UTF-8 in featured result")
        }
        
        return try JSONDecoder().decode([JSAnimePreview].self, from: jsonData)
    }
    
    /// Unloads this source from the runtime.
    func unload() async {
        await runtime.unloadSource(sourceId: sourceId)
    }
}
