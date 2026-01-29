//
//  SourceManager.swift
//  Haishin
//
//  Created by Tan Nghia La on 24.01.26.
//

import Foundation

/// Manages video sources including installation, loading, and execution.
@Observable
final class SourceManager: SourceManaging {

    //#################################################################################
    // MARK: - Constants
    //#################################################################################

    private struct Constants {
        static let defaultRepositoryAddedKey = "defaultRepositoryAdded"
        static let repositoryURLsKey = "repositoryURLs"
        static let defaultRepositoryURL = "https://raw.githubusercontent.com/mollywoodnini/Haishin-example-sources/main/manifest.json"
    }


    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    /// Shared instance for app-wide use.
    static let shared = SourceManager()

    /// Currently installed sources.
    private(set) var installedSources: [InstalledSource] = []

    /// Available source repositories.
    private(set) var repositories: [SourceRepository] = []

    /// Sources that have updates available (keyed by source ID).
    private(set) var availableUpdates: [String: SourceInfo] = [:]

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
        self.sourcesDirectory = appSupport.appendingPathComponent("Haishin/Sources",
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

            // Add default repository on first launch
            await addDefaultRepositoryIfNeeded()

            let sourceFiles = try fileManager.contentsOfDirectory(at: sourcesDirectory,
                                                                   includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "js" }
                // Sort so that files with proper names (e.g., "archive.org") come before
                // UUID-named files, ensuring we keep the correctly named one
                .sorted { $0.lastPathComponent < $1.lastPathComponent }

            var sources: [InstalledSource] = []
            var seenIds: [String: URL] = [:]
            var duplicateFiles: [URL] = []

            for file in sourceFiles {
                do {
                    let source = try await loadSource(from: file)
                    let expectedFilename = "\(source.id).js"
                    
                    // Check for duplicate source IDs
                    if let existingFile = seenIds[source.id] {
                        // Prefer the file with the correct name
                        if file.lastPathComponent == expectedFilename {
                            // Current file has correct name, mark existing as duplicate
                            Log.debug(.sources, "Found correctly named file for '\(source.id)', replacing previous")
                            duplicateFiles.append(existingFile)
                            sources.removeAll { $0.id == source.id }
                            seenIds[source.id] = file
                            sources.append(source)
                        } else {
                            // Current file has wrong name, mark it as duplicate
                            Log.debug(.sources, "Duplicate source ID '\(source.id)' at \(file.lastPathComponent), skipping")
                            duplicateFiles.append(file)
                        }
                        continue
                    }
                    
                    seenIds[source.id] = file
                    sources.append(source)
                } catch {
                    Log.error(.sources, "Failed to load source at \(file): \(error)")
                }
            }
            
            // Clean up duplicate files
            for duplicateFile in duplicateFiles {
                Log.debug(.sources, "Removing duplicate source file: \(duplicateFile.lastPathComponent)")
                try? fileManager.removeItem(at: duplicateFile)
            }

            installedSources = sources
        } catch {
            lastError = error
            Log.error(.sources, "Failed to load sources: \(error)")
        }
    }

    /// Adds a source repository.
    /// - Parameter url: URL to the repository manifest.
    func addRepository(url: URL) async throws {
        let data = try await networkClient.fetch(url: url, headers: nil, ignoreCache: true)
        let manifest = try Self.decode(RepositoryManifest.self, from: data)

        let repository = SourceRepository(name: manifest.name,
                                          url: url,
                                          sources: manifest.sources)

        if !repositories.contains(where: { $0.url == url }) {
            repositories.append(repository)
            saveRepositoryURLs()
            checkForUpdates()
        }
    }

    /// Removes a repository.
    /// - Parameter repository: The repository to remove.
    func removeRepository(_ repository: SourceRepository) {
        repositories.removeAll { $0.url == repository.url }
        saveRepositoryURLs()
        checkForUpdates()
    }

    /// Refreshes all repositories to check for new sources and updates.
    func refreshRepositories() async {
        Log.info(.sources, "Refreshing \(repositories.count) repositories")

        let urls = repositories.map { $0.url }
        repositories.removeAll()

        for url in urls {
            do {
                try await addRepository(url: url)
                Log.debug(.sources, "Refreshed repository: \(url)")
            } catch {
                Log.error(.sources, "Failed to refresh repository \(url): \(error)")
            }
        }

        checkForUpdates()
    }

    /// Loads saved repositories from UserDefaults.
    func loadSavedRepositories() async {
        let userDefaults = UserDefaults.standard
        guard let urlStrings = userDefaults.stringArray(forKey: Constants.repositoryURLsKey) else {
            Log.debug(.sources, "No saved repositories found")
            return
        }

        Log.info(.sources, "Loading \(urlStrings.count) saved repositories")

        for urlString in urlStrings {
            guard let url = URL(string: urlString) else {
                Log.warning(.sources, "Invalid repository URL: \(urlString)")
                continue
            }

            do {
                try await addRepository(url: url)
                Log.debug(.sources, "Loaded repository: \(url)")
            } catch {
                Log.error(.sources, "Failed to load repository \(url): \(error)")
            }
        }
    }

    /// Checks if an update is available for a source.
    /// - Parameter sourceId: The source ID to check.
    /// - Returns: The new version info if an update is available, nil otherwise.
    func getAvailableUpdate(for sourceId: String) -> SourceInfo? {
        availableUpdates[sourceId]
    }

    /// Updates a source to the latest version from its repository.
    /// - Parameter sourceId: The source ID to update.
    func updateSource(sourceId: String) async throws {
        guard let updateInfo = availableUpdates[sourceId] else {
            Log.warning(.sources, "No update available for \(sourceId)")
            return
        }

        // Find the repository containing this source
        guard let repository = repositories.first(where: { repo in
            repo.sources.contains { $0.id == sourceId }
        }) else {
            Log.error(.sources, "Repository not found for source \(sourceId)")
            throw SourceError.sourceNotFound
        }

        Log.info(.sources, "Updating \(sourceId) to v\(updateInfo.version)")

        // Download and install the new version (overwrites existing)
        let scriptURL = repository.url
            .deletingLastPathComponent()
            .appendingPathComponent("sources/\(sourceId).js")

        let scriptData = try await networkClient.fetch(url: scriptURL)

        guard let script = String(data: scriptData, encoding: .utf8) else {
            throw SourceError.invalidScript
        }

        // Save the script (overwriting existing)
        let localPath = sourcesDirectory.appendingPathComponent("\(sourceId).js")
        try script.write(to: localPath, atomically: true, encoding: .utf8)

        // Reload the source
        let updatedSource = try await loadSource(from: localPath)

        // Update the installed sources list
        if let index = installedSources.firstIndex(where: { $0.id == sourceId }) {
            installedSources[index] = updatedSource
        }

        // Remove from available updates
        availableUpdates.removeValue(forKey: sourceId)

        Log.info(.sources, "Successfully updated \(sourceId) to v\(updateInfo.version)")
    }

    /// Updates all sources that have updates available.
    func updateAllSources() async {
        let sourceIds = Array(availableUpdates.keys)
        Log.info(.sources, "Updating \(sourceIds.count) sources")

        for sourceId in sourceIds {
            do {
                try await updateSource(sourceId: sourceId)
            } catch {
                Log.error(.sources, "Failed to update \(sourceId): \(error)")
            }
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
    /// - Parameter urlString: The URL to the source JavaScript file (can be HTTP/HTTPS or file:// URL).
    func installSource(fromURL urlString: String) async throws {
        Log.info(.sources, "Installing source from: \(urlString)")
        
        let script: String
        
        // Handle file:// URLs and local paths
        if urlString.hasPrefix("file://") || urlString.hasPrefix("/") {
            Log.debug(.sources, "Handling as local file")
            let fileURL: URL
            if urlString.hasPrefix("file://") {
                guard let url = URL(string: urlString) else {
                    Log.error(.sources, "Failed to create URL from file:// string")
                    throw SourceError.invalidScript
                }
                fileURL = url
            } else {
                fileURL = URL(fileURLWithPath: urlString)
            }
            
            Log.debug(.sources, "Reading file at: \(fileURL.path)")
            script = try String(contentsOf: fileURL, encoding: .utf8)
            Log.debug(.sources, "Successfully read \(script.count) characters")
        } else {
            Log.debug(.sources, "Handling as remote URL")
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
        
        Log.debug(.sources, "Loading script into temporary runtime")
        // Extract source ID from the script by creating a temporary runtime
        let tempRuntime = try JSRuntime(networkClient: networkClient)
        let tempId = UUID().uuidString
        try await tempRuntime.loadSource(script: script, sourceId: tempId)
        let info = try await tempRuntime.getSourceInfo(sourceId: tempId)
        
        Log.debug(.sources, "Source info: \(info.name) v\(info.version)")
        
        // Check if already installed
        if installedSources.contains(where: { $0.id == info.id }) {
            Log.warning(.sources, "Source already installed")
            throw SourceError.alreadyInstalled
        }
        
        // Save the script
        let localPath = sourcesDirectory.appendingPathComponent("\(info.id).js")
        Log.debug(.sources, "Saving to: \(localPath.path)")
        try script.write(to: localPath, atomically: true, encoding: .utf8)
        
        // Load the source
        Log.debug(.sources, "Loading source into runtime")
        let installedSource = try await loadSource(from: localPath)
        installedSources.append(installedSource)
        
        Log.info(.sources, "Installation complete!")
    }

    /// Uninstalls a source.
    /// - Parameter sourceId: The source ID to uninstall.
    func uninstallSource(sourceId: String) throws {
        // Find the installed source to get the actual file path
        guard let installedSource = installedSources.first(where: { $0.id == sourceId }) else {
            Log.warning(.sources, "Source '\(sourceId)' not found in installed sources")
            return
        }
        
        // Delete the actual script file (handles both correctly-named and UUID-named files)
        let actualPath = installedSource.scriptPath
        Log.info(.sources, "Uninstalling source '\(sourceId)' at: \(actualPath.lastPathComponent)")
        
        if fileManager.fileExists(atPath: actualPath.path) {
            try fileManager.removeItem(at: actualPath)
            Log.debug(.sources, "Deleted file: \(actualPath.lastPathComponent)")
        }

        installedSources.removeAll { $0.id == sourceId }
        
        // Clean up the JS source
        Task {
            await jsSources[sourceId]?.unload()
            jsSources.removeValue(forKey: sourceId)
        }
    }

    /// Gets the popular videos from a source.
    /// - Parameters:
    ///   - sourceId: The source to query.
    ///   - page: Page number.
    /// - Returns: List of video previews.
    func getPopular(sourceId: String, page: Int) async throws -> [VideoPreview] {
        guard let jsSource = jsSources[sourceId] else {
            throw SourceError.sourceNotFound
        }
        
        let entryVideos = try await jsSource.getEntryVideos()
        return entryVideos.map { convertToVideoPreview($0, sourceId: sourceId) }
    }

    /// Searches for videos in a source.
    /// - Parameters:
    ///   - sourceId: The source to search.
    ///   - query: Search query.
    ///   - page: Page number.
    /// - Returns: List of matching video previews.
    func search(sourceId: String, query: String, page: Int) async throws -> [VideoPreview] {
        guard let jsSource = jsSources[sourceId] else {
            throw SourceError.sourceNotFound
        }
        
        let searchResult = try await jsSource.search(query: query, page: page)
        return searchResult.results.map { convertToVideoPreview($0, sourceId: sourceId) }
    }

    /// Gets full video details.
    /// - Parameters:
    ///   - sourceId: The source.
    ///   - url: The video details URL.
    /// - Returns: Full video information.
    func getVideoDetails(sourceId: String, url: String) async throws -> Video {
        guard let jsSource = jsSources[sourceId] else {
            throw SourceError.sourceNotFound
        }
        
        guard let videoUrl = URL(string: url) else {
            throw SourceError.invalidResponse
        }
        
        // Extract video ID from URL (typically the last path component)
        let videoId = videoUrl.lastPathComponent
        
        let details = try await jsSource.getVideoDetails(videoId: videoId, videoUrl: videoUrl)
        return try convertToVideo(details, sourceId: sourceId, detailsURL: url)
    }

    /// Gets video sources for an episode.
    /// - Parameters:
    ///   - sourceId: The source.
    ///   - episodeId: The episode identifier.
    ///   - url: The episode URL.
    /// - Returns: Playback information.
    func getVideoSources(sourceId: String, episodeId: String, url: String) async throws -> PlaybackInfo {
        guard let jsSource = jsSources[sourceId] else {
            throw SourceError.sourceNotFound
        }
        
        guard let episodeUrl = URL(string: url) else {
            throw SourceError.invalidResponse
        }
        
        // For now, use the first available server (in a real app, let user choose)
        // We'll need to get video details first to know available servers
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

    /// Saves repository URLs to UserDefaults for persistence.
    private func saveRepositoryURLs() {
        let urls = repositories.map { $0.url.absoluteString }
        UserDefaults.standard.set(urls, forKey: Constants.repositoryURLsKey)
        Log.debug(.sources, "Saved \(urls.count) repository URLs")
    }

    /// Checks for available updates by comparing installed versions with repository versions.
    private func checkForUpdates() {
        var updates: [String: SourceInfo] = [:]

        for repository in repositories {
            for repoSource in repository.sources {
                // Check if this source is installed
                guard let installed = installedSources.first(where: { $0.id == repoSource.id }) else {
                    continue
                }

                // Compare versions
                if isVersion(repoSource.version, newerThan: installed.info.version) {
                    updates[repoSource.id] = repoSource
                    Log.info(.sources, "Update available: \(repoSource.id) \(installed.info.version) -> \(repoSource.version)")
                }
            }
        }

        availableUpdates = updates
        Log.debug(.sources, "Found \(updates.count) available updates")
    }

    /// Compares two semantic version strings.
    /// - Parameters:
    ///   - version1: The first version string.
    ///   - version2: The second version string.
    /// - Returns: True if version1 is newer than version2.
    private func isVersion(_ version1: String, newerThan version2: String) -> Bool {
        let v1Components = version1.split(separator: ".").compactMap { Int($0) }
        let v2Components = version2.split(separator: ".").compactMap { Int($0) }

        // Pad arrays to same length
        let maxLength = max(v1Components.count, v2Components.count)
        let v1Padded = v1Components + Array(repeating: 0, count: maxLength - v1Components.count)
        let v2Padded = v2Components + Array(repeating: 0, count: maxLength - v2Components.count)

        for (comp1, comp2) in zip(v1Padded, v2Padded) {
            if comp1 > comp2 { return true }
            if comp1 < comp2 { return false }
        }

        return false // Versions are equal
    }

    /// Adds the default repository on first launch.
    private func addDefaultRepositoryIfNeeded() async {
        let userDefaults = UserDefaults.standard

        // Check if default repository has already been added
        guard !userDefaults.bool(forKey: Constants.defaultRepositoryAddedKey) else {
            Log.debug(.sources, "Default repository already added, skipping")
            return
        }

        Log.info(.sources, "Adding default repository for first launch")

        guard let url = URL(string: Constants.defaultRepositoryURL) else {
            Log.error(.sources, "Invalid default repository URL")
            return
        }

        do {
            try await addRepository(url: url)
            Log.info(.sources, "Successfully added default repository")
        } catch {
            Log.error(.sources, "Failed to add default repository: \(error)")
        }

        // Mark default repository as added (even if it failed, to avoid repeated attempts)
        userDefaults.set(true, forKey: Constants.defaultRepositoryAddedKey)
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
                               installedAt: installedAt)
    }

    // MARK: - Conversion Methods
    
    /// Converts a JSVideoPreview to VideoPreview
    private func convertToVideoPreview(_ jsPreview: JSVideoPreview, sourceId: String) -> VideoPreview {
        return VideoPreview(id: jsPreview.id,
                            title: jsPreview.title.decodingHTMLEntities(),
                            coverURL: jsPreview.coverUrl.flatMap { URL(string: $0) },
                            sourceId: sourceId,
                            detailsURL: jsPreview.url)
    }
    
    /// Converts JSVideoDetails to Video
    private func convertToVideo(_ jsDetails: JSVideoDetails,
                                sourceId: String,
                                detailsURL: String) throws -> Video {
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
        
        return Video(id: jsDetails.id,
                     title: jsDetails.title.decodingHTMLEntities(),
                     alternativeTitles: jsDetails.englishTitle.map { [$0.decodingHTMLEntities()] } ?? [],
                     coverURL: jsDetails.coverUrl.flatMap { URL(string: $0) },
                     bannerURL: nil, // JS sources don't typically provide banner
                     synopsis: jsDetails.synopsis?.decodingHTMLEntities(),
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
                       title: jsEpisode.title.decodingHTMLEntities(),
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
                        headers: stream.headers,
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

    /// Decodes JSON data in a nonisolated context to avoid MainActor isolation issues.
    nonisolated private static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try JSONDecoder().decode(type, from: data)
    }
}


//#################################################################################
// MARK: - Supporting Types
//#################################################################################

/// Repository manifest structure.
private struct RepositoryManifest: Codable, Sendable {
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
