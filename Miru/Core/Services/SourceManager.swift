//
//  SourceManager.swift
//  Miru
//
//  Created by Miru on 24.01.26.
//

import Foundation

/// Manages anime sources including installation, loading, and execution.
@Observable
final class SourceManager: SourceManaging {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    /// Currently installed sources.
    private(set) var installedSources: [InstalledSource] = []

    /// Available source repositories.
    private(set) var repositories: [SourceRepository] = []

    /// Whether sources are currently being loaded.
    private(set) var isLoading = false

    /// Last error that occurred.
    private(set) var lastError: Error?

    private let networkClient: NetworkClient
    private let fileManager: FileManager
    private let sourcesDirectory: URL
    private var jsRuntime: JSRuntime?
    private var jsSources: [String: JavaScriptSource] = [:]


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new source manager.
    /// - Parameters:
    ///   - networkClient: Network client for fetching sources.
    ///   - fileManager: File manager for source storage.
    init(networkClient: NetworkClient = NetworkClient(),
         fileManager: FileManager = .default) {
        self.networkClient = networkClient
        self.fileManager = fileManager

        // Set up sources directory in Application Support
        let appSupport = fileManager.urls(for: .applicationSupportDirectory,
                                          in: .userDomainMask).first!
        self.sourcesDirectory = appSupport.appendingPathComponent("Miru/Sources",
                                                                   isDirectory: true)

        createSourcesDirectoryIfNeeded()
    }


    //#################################################################################
    // MARK: - Public Methods
    //#################################################################################

    /// Loads all installed sources.
    func loadInstalledSources() async {
        isLoading = true
        defer { isLoading = false }

        do {
            jsRuntime = try JSRuntime(networkClient: networkClient)

            let sourceFiles = try fileManager.contentsOfDirectory(at: sourcesDirectory,
                                                                   includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "js" }

            var sources: [InstalledSource] = []

            for file in sourceFiles {
                do {
                    let source = try await loadSource(from: file)
                    sources.append(source)
                } catch {
                    print("[SourceManager] Failed to load source at \(file): \(error)")
                }
            }

            installedSources = sources
        } catch {
            lastError = error
            print("[SourceManager] Failed to load sources: \(error)")
        }
    }

    /// Adds a source repository.
    /// - Parameter url: URL to the repository manifest.
    func addRepository(url: URL) async throws {
        let manifest = try await networkClient.fetchJSON(url: url,
                                                         type: RepositoryManifest.self)

        let repository = SourceRepository(name: manifest.name,
                                          url: url,
                                          sources: manifest.sources)

        if !repositories.contains(where: { $0.url == url }) {
            repositories.append(repository)
        }
    }

    /// Installs a source from a repository.
    /// - Parameters:
    ///   - source: The source info to install.
    ///   - repository: The repository containing the source.
    func installSource(_ source: SourceInfo, from repository: SourceRepository) async throws {
        let scriptURL = repository.url
            .deletingLastPathComponent()
            .appendingPathComponent("sources/\(source.id).js")

        let scriptData = try await networkClient.fetch(url: scriptURL)

        guard let script = String(data: scriptData, encoding: .utf8) else {
            throw SourceError.invalidScript
        }

        // Save the script
        let localPath = sourcesDirectory.appendingPathComponent("\(source.id).js")
        try script.write(to: localPath, atomically: true, encoding: .utf8)

        // Load the source
        let installedSource = try await loadSource(from: localPath)
        installedSources.append(installedSource)
    }
    
    /// Installs a source from a URL string.
    /// - Parameter urlString: The URL to the source JavaScript file (can be HTTP/HTTPS or file:// URL).
    func installSource(fromURL urlString: String) async throws {
        print("[SourceManager] Installing source from: \(urlString)")
        
        let script: String
        
        // Handle file:// URLs and local paths
        if urlString.hasPrefix("file://") || urlString.hasPrefix("/") {
            print("[SourceManager] Handling as local file")
            let fileURL: URL
            if urlString.hasPrefix("file://") {
                guard let url = URL(string: urlString) else {
                    print("[SourceManager] Failed to create URL from file:// string")
                    throw SourceError.invalidScript
                }
                fileURL = url
            } else {
                fileURL = URL(fileURLWithPath: urlString)
            }
            
            print("[SourceManager] Reading file at: \(fileURL.path)")
            script = try String(contentsOf: fileURL, encoding: .utf8)
            print("[SourceManager] Successfully read \(script.count) characters")
        } else {
            print("[SourceManager] Handling as remote URL")
            // Handle HTTP/HTTPS URLs
            guard let url = URL(string: urlString) else {
                throw SourceError.invalidScript
            }
            
            let scriptData = try await networkClient.fetch(url: url)
            
            guard let scriptString = String(data: scriptData, encoding: .utf8) else {
                throw SourceError.invalidScript
            }
            script = scriptString
        }
        
        print("[SourceManager] Loading script into temporary runtime")
        // Extract source ID from the script by creating a temporary runtime
        let tempRuntime = try JSRuntime(networkClient: networkClient)
        let tempId = UUID().uuidString
        try await tempRuntime.loadSource(script: script, sourceId: tempId)
        let info = try await tempRuntime.getSourceInfo(sourceId: tempId)
        
        print("[SourceManager] Source info: \(info.name) v\(info.version)")
        
        // Check if already installed
        if installedSources.contains(where: { $0.id == info.id }) {
            print("[SourceManager] Source already installed")
            throw SourceError.alreadyInstalled
        }
        
        // Save the script
        let localPath = sourcesDirectory.appendingPathComponent("\(info.id).js")
        print("[SourceManager] Saving to: \(localPath.path)")
        try script.write(to: localPath, atomically: true, encoding: .utf8)
        
        // Load the source
        print("[SourceManager] Loading source into runtime")
        let installedSource = try await loadSource(from: localPath)
        installedSources.append(installedSource)
        
        print("[SourceManager] Installation complete!")
    }

    /// Uninstalls a source.
    /// - Parameter sourceId: The source ID to uninstall.
    func uninstallSource(sourceId: String) throws {
        let path = sourcesDirectory.appendingPathComponent("\(sourceId).js")

        if fileManager.fileExists(atPath: path.path) {
            try fileManager.removeItem(at: path)
        }

        installedSources.removeAll { $0.id == sourceId }
        
        // Clean up the JS source
        Task {
            await jsSources[sourceId]?.unload()
            jsSources.removeValue(forKey: sourceId)
        }
    }

    /// Gets the popular anime from a source.
    /// - Parameters:
    ///   - sourceId: The source to query.
    ///   - page: Page number.
    /// - Returns: List of anime previews.
    func getPopular(sourceId: String, page: Int) async throws -> [AnimePreview] {
        // For JavaScript sources, getFeatured() maps to getPopular
        guard let jsSource = jsSources[sourceId] else {
            throw SourceError.sourceNotFound
        }
        
        let featured = try await jsSource.getFeatured()
        return featured.map { convertToAnimePreview($0, sourceId: sourceId) }
    }

    /// Gets the latest anime from a source.
    /// - Parameters:
    ///   - sourceId: The source to query.
    ///   - page: Page number.
    /// - Returns: List of anime previews.
    func getLatest(sourceId: String, page: Int) async throws -> [AnimePreview] {
        // For JavaScript sources, we use getFeatured() for both popular and latest
        // Individual sources can differentiate in their implementation
        guard let jsSource = jsSources[sourceId] else {
            throw SourceError.sourceNotFound
        }
        
        let featured = try await jsSource.getFeatured()
        return featured.map { convertToAnimePreview($0, sourceId: sourceId) }
    }

    /// Searches for anime in a source.
    /// - Parameters:
    ///   - sourceId: The source to search.
    ///   - query: Search query.
    ///   - page: Page number.
    /// - Returns: List of matching anime previews.
    func search(sourceId: String, query: String, page: Int) async throws -> [AnimePreview] {
        guard let jsSource = jsSources[sourceId] else {
            throw SourceError.sourceNotFound
        }
        
        let searchResult = try await jsSource.search(query: query, page: page)
        return searchResult.results.map { convertToAnimePreview($0, sourceId: sourceId) }
    }

    /// Gets full anime details.
    /// - Parameters:
    ///   - sourceId: The source.
    ///   - url: The anime details URL.
    /// - Returns: Full anime information.
    func getAnimeDetails(sourceId: String, url: String) async throws -> Anime {
        guard let jsSource = jsSources[sourceId] else {
            throw SourceError.sourceNotFound
        }
        
        guard let animeUrl = URL(string: url) else {
            throw SourceError.invalidResponse
        }
        
        // Extract anime ID from URL (typically the last path component)
        let animeId = animeUrl.lastPathComponent
        
        let details = try await jsSource.getAnimeDetails(animeId: animeId, animeUrl: animeUrl)
        return try convertToAnime(details, sourceId: sourceId, detailsURL: url)
    }

    /// Gets video sources for an episode.
    /// - Parameters:
    ///   - sourceId: The source.
    ///   - url: The episode URL.
    /// - Returns: Playback information.
    func getVideoSources(sourceId: String, url: String) async throws -> PlaybackInfo {
        guard let jsSource = jsSources[sourceId] else {
            throw SourceError.sourceNotFound
        }
        
        guard let episodeUrl = URL(string: url) else {
            throw SourceError.invalidResponse
        }
        
        // Extract episode ID from URL
        let episodeId = episodeUrl.lastPathComponent
        
        // For now, use the first available server (in a real app, let user choose)
        // We'll need to get anime details first to know available servers
        // For simplicity, we'll use "default" as server name
        let streams = try await jsSource.getEpisodeStreams(episodeId: episodeId,
                                                            episodeUrl: episodeUrl,
                                                            server: "default")
        
        return try convertToPlaybackInfo(streams, episodeId: episodeId)
    }


    //#################################################################################
    // MARK: - Private Methods
    //#################################################################################

    private func createSourcesDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: sourcesDirectory.path) {
            try? fileManager.createDirectory(at: sourcesDirectory,
                                             withIntermediateDirectories: true)
        }
    }

    private func loadSource(from path: URL) async throws -> InstalledSource {
        let script = try String(contentsOf: path, encoding: .utf8)
        let sourceId = path.deletingPathExtension().lastPathComponent

        guard let runtime = jsRuntime else {
            throw SourceError.invalidScript
        }
        
        // Create JavaScriptSource actor
        let jsSource = try await JavaScriptSource(script: script,
                                                   sourceId: sourceId,
                                                   runtime: runtime)
        
        // Store the JS source
        jsSources[sourceId] = jsSource
        
        let attributes = try fileManager.attributesOfItem(atPath: path.path)
        let installedAt = attributes[.creationDate] as? Date ?? Date()

        return InstalledSource(info: jsSource.info,
                               scriptPath: path,
                               isEnabled: await jsSource.isEnabled,
                               installedAt: installedAt)
    }

    // MARK: - Conversion Methods
    
    /// Converts a JSAnimePreview to AnimePreview
    private func convertToAnimePreview(_ jsPreview: JSAnimePreview, sourceId: String) -> AnimePreview {
        return AnimePreview(id: jsPreview.id,
                            title: jsPreview.title,
                            coverURL: URL(string: jsPreview.coverUrl),
                            sourceId: sourceId,
                            detailsURL: jsPreview.url)
    }
    
    /// Converts JSAnimeDetails to Anime
    private func convertToAnime(_ jsDetails: JSAnimeDetails,
                                sourceId: String,
                                detailsURL: String) throws -> Anime {
        // Convert episodes from server-grouped to flat list
        // For now, use the first available server's episodes
        let episodes: [Episode]
        if let firstServerEpisodes = jsDetails.episodes.values.first {
            episodes = firstServerEpisodes.map { convertToEpisode($0) }
        } else {
            episodes = []
        }
        
        // Convert episode ranges from server-grouped to flat list
        // For now, use the first available server's ranges
        let episodeRanges: [EpisodeRange]
        if let firstServerRanges = jsDetails.episodeRanges?.values.first, !firstServerRanges.isEmpty {
            episodeRanges = firstServerRanges.map { convertToEpisodeRange($0) }
        } else {
            // Fallback: create a single range containing all episodes
            if !episodes.isEmpty {
                episodeRanges = [EpisodeRange(id: "0",
                                              title: "All Episodes",
                                              episodes: episodes)]
            } else {
                episodeRanges = []
            }
        }
        
        // Convert status
        let status: AiringStatus
        switch jsDetails.status {
        case .ongoing:
            status = .ongoing
        case .completed:
            status = .completed
        case .upcoming:
            status = .upcoming
        case .unknown:
            status = .unknown
        }
        
        return Anime(id: jsDetails.id,
                     title: jsDetails.title,
                     alternativeTitles: jsDetails.englishTitle.map { [$0] } ?? [],
                     coverURL: URL(string: jsDetails.coverUrl),
                     bannerURL: nil, // JS sources don't typically provide banner
                     synopsis: jsDetails.synopsis,
                     genres: jsDetails.genres,
                     status: status,
                     year: extractYear(from: jsDetails.releaseDate),
                     rating: jsDetails.rating.map { String(format: "%.1f", $0) },
                     sourceId: sourceId,
                     detailsURL: detailsURL,
                     episodes: episodes,
                     episodeRanges: episodeRanges)
    }
    
    /// Converts SourceEpisodeRange to EpisodeRange
    private func convertToEpisodeRange(_ jsRange: SourceEpisodeRange) -> EpisodeRange {
        return EpisodeRange(id: jsRange.id,
                            title: jsRange.title,
                            episodes: jsRange.episodes.map { convertToEpisode($0) })
    }
    
    /// Converts SourceEpisode to Episode
    private func convertToEpisode(_ jsEpisode: SourceEpisode) -> Episode {
        return Episode(id: jsEpisode.id,
                       number: String(jsEpisode.number),
                       title: jsEpisode.title,
                       thumbnailURL: nil, // JS sources don't typically provide thumbnails
                       url: jsEpisode.url,
                       duration: nil)
    }
    
    /// Converts JSEpisodeStream to PlaybackInfo
    private func convertToPlaybackInfo(_ jsStream: JSEpisodeStream, episodeId: String) throws -> PlaybackInfo {
        let videoSources = jsStream.streams.map { stream -> VideoSource in
            VideoSource(id: UUID().uuidString,
                        serverName: "Default",
                        quality: stream.quality,
                        url: URL(string: stream.url)!,
                        headers: nil,
                        requiresExtraction: false)
        }
        
        let subtitles = jsStream.subtitles?.map { sub -> Subtitle in
            Subtitle(id: UUID().uuidString,
                     language: sub.language,
                     label: sub.label ?? sub.language,
                     url: URL(string: sub.url)!)
        } ?? []
        
        return PlaybackInfo(episodeId: episodeId,
                            sources: videoSources,
                            subtitles: subtitles)
    }
    
    /// Extracts year from ISO 8601 date string
    private func extractYear(from dateString: String?) -> Int? {
        guard let dateString = dateString else { return nil }
        
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString) {
            let calendar = Calendar.current
            return calendar.component(.year, from: date)
        }
        
        // Fallback: try to extract year from string (e.g., "2023-01-01")
        if let year = Int(dateString.prefix(4)) {
            return year
        }
        
        return nil
    }
}


//#################################################################################
// MARK: - Supporting Types
//#################################################################################

/// Repository manifest structure.
private struct RepositoryManifest: Codable {
    let name: String
    let sources: [SourceInfo]
}

/// Errors related to source operations.
enum SourceError: LocalizedError {
    case invalidScript
    case invalidResponse
    case sourceNotFound
    case alreadyInstalled

    var errorDescription: String? {
        switch self {
        case .invalidScript:
            return "The source script is invalid."
        case .invalidResponse:
            return "Received invalid response from source."
        case .sourceNotFound:
            return "Source not found."
        case .alreadyInstalled:
            return "Source is already installed."
        }
    }
}
