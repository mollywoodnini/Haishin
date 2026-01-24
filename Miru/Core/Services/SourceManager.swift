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
    /// - Parameter urlString: The URL to the source JavaScript file.
    func installSource(fromURL urlString: String) async throws {
        guard let url = URL(string: urlString) else {
            throw SourceError.invalidScript
        }
        
        let scriptData = try await networkClient.fetch(url: url)
        
        guard let script = String(data: scriptData, encoding: .utf8) else {
            throw SourceError.invalidScript
        }
        
        // Extract source ID from the script by creating a temporary runtime
        let tempRuntime = try JSRuntime(networkClient: networkClient)
        let tempId = UUID().uuidString
        try await tempRuntime.loadSource(script: script, sourceId: tempId)
        let info = try await tempRuntime.getSourceInfo(sourceId: tempId)
        
        // Check if already installed
        if installedSources.contains(where: { $0.id == info.id }) {
            throw SourceError.alreadyInstalled
        }
        
        // Save the script
        let localPath = sourcesDirectory.appendingPathComponent("\(info.id).js")
        try script.write(to: localPath, atomically: true, encoding: .utf8)
        
        // Load the source
        let installedSource = try await loadSource(from: localPath)
        installedSources.append(installedSource)
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
        let result = try await jsRuntime?.callFunction(sourceId: sourceId,
                                                       function: "getPopular",
                                                       arguments: [page])
        return try parseAnimeList(from: result, sourceId: sourceId)
    }

    /// Gets the latest anime from a source.
    /// - Parameters:
    ///   - sourceId: The source to query.
    ///   - page: Page number.
    /// - Returns: List of anime previews.
    func getLatest(sourceId: String, page: Int) async throws -> [AnimePreview] {
        let result = try await jsRuntime?.callFunction(sourceId: sourceId,
                                                       function: "getLatest",
                                                       arguments: [page])
        return try parseAnimeList(from: result, sourceId: sourceId)
    }

    /// Searches for anime in a source.
    /// - Parameters:
    ///   - sourceId: The source to search.
    ///   - query: Search query.
    ///   - page: Page number.
    /// - Returns: List of matching anime previews.
    func search(sourceId: String, query: String, page: Int) async throws -> [AnimePreview] {
        let result = try await jsRuntime?.callFunction(sourceId: sourceId,
                                                       function: "search",
                                                       arguments: [query, page])
        return try parseAnimeList(from: result, sourceId: sourceId)
    }

    /// Gets full anime details.
    /// - Parameters:
    ///   - sourceId: The source.
    ///   - url: The anime details URL.
    /// - Returns: Full anime information.
    func getAnimeDetails(sourceId: String, url: String) async throws -> Anime {
        let result = try await jsRuntime?.callFunction(sourceId: sourceId,
                                                       function: "getAnimeDetails",
                                                       arguments: [url])
        return try parseAnime(from: result, sourceId: sourceId)
    }

    /// Gets video sources for an episode.
    /// - Parameters:
    ///   - sourceId: The source.
    ///   - url: The episode URL.
    /// - Returns: Playback information.
    func getVideoSources(sourceId: String, url: String) async throws -> PlaybackInfo {
        let result = try await jsRuntime?.callFunction(sourceId: sourceId,
                                                       function: "getVideoSources",
                                                       arguments: [url])
        return try parsePlaybackInfo(from: result)
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

    private func parseAnimeList(from result: Any?, sourceId: String) throws -> [AnimePreview] {
        guard let array = result as? [[String: Any]] else {
            throw SourceError.invalidResponse
        }

        return array.compactMap { dict -> AnimePreview? in
            guard let id = dict["id"] as? String,
                  let title = dict["title"] as? String,
                  let detailsURL = dict["url"] as? String else {
                return nil
            }

            let coverURL: URL?
            if let coverString = dict["cover"] as? String {
                coverURL = URL(string: coverString)
            } else {
                coverURL = nil
            }

            return AnimePreview(id: id,
                                title: title,
                                coverURL: coverURL,
                                sourceId: sourceId,
                                detailsURL: detailsURL)
        }
    }

    private func parseAnime(from result: Any?, sourceId: String) throws -> Anime {
        guard let dict = result as? [String: Any],
              let id = dict["id"] as? String,
              let title = dict["title"] as? String,
              let detailsURL = dict["url"] as? String else {
            throw SourceError.invalidResponse
        }

        let coverURL: URL?
        if let coverString = dict["cover"] as? String {
            coverURL = URL(string: coverString)
        } else {
            coverURL = nil
        }

        let bannerURL: URL?
        if let bannerString = dict["banner"] as? String {
            bannerURL = URL(string: bannerString)
        } else {
            bannerURL = nil
        }

        let episodes: [Episode]
        if let episodeArray = dict["episodes"] as? [[String: Any]] {
            episodes = episodeArray.compactMap { parseEpisode(from: $0) }
        } else {
            episodes = []
        }

        let statusString = dict["status"] as? String ?? "unknown"
        let status = AiringStatus(rawValue: statusString) ?? .unknown

        return Anime(id: id,
                     title: title,
                     alternativeTitles: dict["alternativeTitles"] as? [String] ?? [],
                     coverURL: coverURL,
                     bannerURL: bannerURL,
                     synopsis: dict["synopsis"] as? String,
                     genres: dict["genres"] as? [String] ?? [],
                     status: status,
                     year: dict["year"] as? Int,
                     rating: dict["rating"] as? String,
                     sourceId: sourceId,
                     detailsURL: detailsURL,
                     episodes: episodes)
    }

    private func parseEpisode(from dict: [String: Any]) -> Episode? {
        guard let id = dict["id"] as? String,
              let number = dict["number"] as? String,
              let url = dict["url"] as? String else {
            return nil
        }

        let thumbnailURL: URL?
        if let thumbString = dict["thumbnail"] as? String {
            thumbnailURL = URL(string: thumbString)
        } else {
            thumbnailURL = nil
        }

        return Episode(id: id,
                       number: number,
                       title: dict["title"] as? String,
                       thumbnailURL: thumbnailURL,
                       url: url,
                       duration: dict["duration"] as? TimeInterval)
    }

    private func parsePlaybackInfo(from result: Any?) throws -> PlaybackInfo {
        guard let dict = result as? [String: Any],
              let episodeId = dict["episodeId"] as? String else {
            throw SourceError.invalidResponse
        }

        let sources: [VideoSource]
        if let sourceArray = dict["sources"] as? [[String: Any]] {
            sources = sourceArray.compactMap { parseVideoSource(from: $0) }
        } else {
            sources = []
        }

        let subtitles: [Subtitle]
        if let subArray = dict["subtitles"] as? [[String: Any]] {
            subtitles = subArray.compactMap { parseSubtitle(from: $0) }
        } else {
            subtitles = []
        }

        return PlaybackInfo(episodeId: episodeId, sources: sources, subtitles: subtitles)
    }

    private func parseVideoSource(from dict: [String: Any]) -> VideoSource? {
        guard let id = dict["id"] as? String,
              let serverName = dict["server"] as? String,
              let urlString = dict["url"] as? String,
              let url = URL(string: urlString) else {
            return nil
        }

        return VideoSource(id: id,
                           serverName: serverName,
                           quality: dict["quality"] as? String,
                           url: url,
                           headers: dict["headers"] as? [String: String],
                           requiresExtraction: dict["requiresExtraction"] as? Bool ?? false)
    }

    private func parseSubtitle(from dict: [String: Any]) -> Subtitle? {
        guard let id = dict["id"] as? String,
              let language = dict["language"] as? String,
              let label = dict["label"] as? String,
              let urlString = dict["url"] as? String,
              let url = URL(string: urlString) else {
            return nil
        }

        return Subtitle(id: id, language: language, label: label, url: url)
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
