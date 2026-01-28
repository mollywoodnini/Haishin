//
//  DownloadService.swift
//  Haishin
//
//  Created by Haishin on 25.01.26.
//

import Foundation


//#################################################################################
// MARK: - DownloadError
//#################################################################################

/// Errors that can occur during download operations.
enum DownloadError: LocalizedError {
    case sourceManagerNotAvailable
    case noVideoSourceFound
    case httpError(statusCode: Int)
    case fileWriteError

    var errorDescription: String? {
        switch self {
        case .sourceManagerNotAvailable:
            return "Source manager is not available"
        case .noVideoSourceFound:
            return "No video source found for this episode"
        case .httpError(let statusCode):
            return "HTTP error: \(statusCode)"
        case .fileWriteError:
            return "Failed to write file to disk"
        }
    }
}


//#################################################################################
// MARK: - DownloadState
//#################################################################################

/// Represents the current state of a download.
enum DownloadState: Codable, Equatable, Hashable {
    case pending
    case downloading(progress: Double)
    case completed
    case failed(error: String)
    case cancelled

    var isActive: Bool {
        switch self {
        case .pending, .downloading:
            return true
        default:
            return false
        }
    }

    var isCompleted: Bool {
        if case .completed = self { return true }
        return false
    }

    var progress: Double {
        switch self {
        case .downloading(let progress):
            return progress
        case .completed:
            return 1.0
        default:
            return 0.0
        }
    }
}


//#################################################################################
// MARK: - DownloadedEpisode
//#################################################################################

/// Represents a downloaded or downloading episode.
struct DownloadedEpisode: Identifiable, Codable, Equatable, Hashable {

    /// Unique identifier for the download.
    let id: String

    /// The anime ID this episode belongs to.
    let animeId: String

    /// The episode ID from the source.
    let episodeId: String

    /// Episode number.
    let episodeNumber: String

    /// Episode title.
    let episodeTitle: String?

    /// The source ID used for downloading.
    let sourceId: String

    /// The source name for display.
    let sourceName: String

    /// URL to fetch the video from.
    let sourceURL: String

    /// Local file path where the video is stored (when completed).
    var localFilePath: String?

    /// Current download state.
    var state: DownloadState

    /// Date when download was initiated.
    let createdAt: Date

    /// Date when download completed (if applicable).
    var completedAt: Date?
}


//#################################################################################
// MARK: - DownloadedAnime
//#################################################################################

/// Represents an anime with downloaded episodes.
struct DownloadedAnime: AnimeProtocol, Codable, Equatable {

    /// The anime ID.
    let id: String

    /// The anime title.
    let title: String

    /// URL to the cover image.
    let coverURL: URL?

    /// The source ID used for downloads.
    let sourceId: String

    /// The source name for display.
    let sourceName: String

    /// All downloaded episodes for this anime.
    var episodes: [DownloadedEpisode]

    /// Number of episodes currently downloading.
    var inProgressCount: Int {
        episodes.filter { $0.state.isActive }.count
    }

    /// Number of completed downloads.
    var completedCount: Int {
        episodes.filter { $0.state.isCompleted }.count
    }

    /// Total download count.
    var totalCount: Int {
        episodes.count
    }

    /// Average progress of active downloads.
    var averageProgress: Double {
        let activeEpisodes = episodes.filter { $0.state.isActive }
        guard !activeEpisodes.isEmpty else { return 0 }
        let totalProgress = activeEpisodes.reduce(0.0) { $0 + $1.state.progress }
        return totalProgress / Double(activeEpisodes.count)
    }
}


//#################################################################################
// MARK: - DownloadServiceProtocol
//#################################################################################

/// Protocol for download management.
@MainActor
protocol DownloadServiceProtocol: AnyObject {
    /// All downloaded anime.
    var downloadedAnime: [DownloadedAnime] { get }

    /// All active downloads.
    var activeDownloads: [DownloadedEpisode] { get }

    /// Total count of downloaded episodes.
    var totalDownloadsCount: Int { get }

    /// Sets the source manager for video extraction.
    func setSourceManager(_ sourceManager: SourceManaging)

    /// Starts downloading an episode.
    func startDownload(animeId: String,
                       animeTitle: String,
                       animeCoverURL: URL?,
                       episodeId: String,
                       episodeNumber: String,
                       episodeTitle: String?,
                       sourceId: String,
                       sourceName: String,
                       sourceURL: String)

    /// Cancels a download.
    func cancelDownload(episodeId: String)

    /// Removes a completed download.
    func removeDownload(episodeId: String)

    /// Gets the download state for an episode.
    func getDownloadState(episodeId: String) -> DownloadState?

    /// Gets all downloads for an anime.
    func getDownloads(forAnimeId animeId: String) -> [DownloadedEpisode]

    /// Removes all downloads for an anime.
    func removeAllDownloads(forAnimeId animeId: String)
}


//#################################################################################
// MARK: - DownloadService
//#################################################################################

/// Service for managing episode downloads.
@Observable
@MainActor
final class DownloadService: DownloadServiceProtocol {

    //#################################################################################
    // MARK: - Constants
    //#################################################################################

    private struct Constants {
        static let episodesStorageKey = "downloadedEpisodes"
        static let animeStorageKey = "downloadedAnimeMetadata"
        static let downloadsDirectory = "Downloads"
    }


    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    /// Shared instance for app-wide use.
    static let shared = DownloadService()

    /// All downloaded anime grouped.
    private(set) var downloadedAnime: [DownloadedAnime] = []

    /// All active downloads.
    var activeDownloads: [DownloadedEpisode] {
        allEpisodes.filter { $0.state.isActive }
    }

    /// Total count of downloaded episodes.
    var totalDownloadsCount: Int {
        allEpisodes.count
    }

    private var allEpisodes: [DownloadedEpisode] = []
    private var downloadTasks: [String: Task<Void, Never>] = [:]
    private let userDefaults: UserDefaults
    private let fileManager: FileManager
    private var sourceManager: SourceManaging?
    private var downloadsDirectory: URL {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent(Constants.downloadsDirectory)
    }


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new download service.
    /// - Parameters:
    ///   - userDefaults: The UserDefaults instance to use for persistence.
    ///   - fileManager: The FileManager instance to use for file operations.
    init(userDefaults: UserDefaults = .standard,
         fileManager: FileManager = .default) {
        self.userDefaults = userDefaults
        self.fileManager = fileManager
        loadDownloads()
    }

    /// Sets the source manager for video extraction.
    /// - Parameter sourceManager: The source manager to use.
    func setSourceManager(_ sourceManager: SourceManaging) {
        self.sourceManager = sourceManager
    }


    //#################################################################################
    // MARK: - Public Methods
    //#################################################################################

    func startDownload(animeId: String,
                       animeTitle: String,
                       animeCoverURL: URL?,
                       episodeId: String,
                       episodeNumber: String,
                       episodeTitle: String?,
                       sourceId: String,
                       sourceName: String,
                       sourceURL: String) {
        // Check if already downloading
        if let existing = allEpisodes.first(where: { $0.episodeId == episodeId }) {
            if existing.state.isActive {
                return // Already downloading
            }
            // Remove failed/cancelled download to retry
            removeDownload(episodeId: episodeId)
        }

        let downloadId = UUID().uuidString
        let downloadedEpisode = DownloadedEpisode(id: downloadId,
                                                   animeId: animeId,
                                                   episodeId: episodeId,
                                                   episodeNumber: episodeNumber,
                                                   episodeTitle: episodeTitle,
                                                   sourceId: sourceId,
                                                   sourceName: sourceName,
                                                   sourceURL: sourceURL,
                                                   localFilePath: nil,
                                                   state: .pending,
                                                   createdAt: Date(),
                                                   completedAt: nil)

        allEpisodes.append(downloadedEpisode)
        updateGroupedAnime(animeId: animeId,
                           title: animeTitle,
                           coverURL: animeCoverURL,
                           sourceId: sourceId,
                           sourceName: sourceName)
        saveDownloads()

        // Start the download task
        let capturedEpisodeId = episodeId
        let task = Task {
            await self.performDownload(episodeId: capturedEpisodeId)
        }
        downloadTasks[episodeId] = task
    }

    func cancelDownload(episodeId: String) {
        downloadTasks[episodeId]?.cancel()
        downloadTasks.removeValue(forKey: episodeId)

        // Remove the cancelled download entirely
        if let index = allEpisodes.firstIndex(where: { $0.episodeId == episodeId }) {
            let animeId = allEpisodes[index].animeId
            allEpisodes.remove(at: index)
            refreshGroupedAnime(forAnimeId: animeId)
            saveDownloads()
        }
    }

    func removeDownload(episodeId: String) {
        downloadTasks[episodeId]?.cancel()
        downloadTasks.removeValue(forKey: episodeId)

        if let index = allEpisodes.firstIndex(where: { $0.episodeId == episodeId }) {
            let episode = allEpisodes[index]
            let animeId = episode.animeId

            // Delete local file if exists
            if let filePath = episode.localFilePath {
                try? fileManager.removeItem(atPath: filePath)
            }

            allEpisodes.remove(at: index)
            refreshGroupedAnime(forAnimeId: animeId)
            saveDownloads()
        }
    }

    func getDownloadState(episodeId: String) -> DownloadState? {
        allEpisodes.first { $0.episodeId == episodeId }?.state
    }

    func getDownloads(forAnimeId animeId: String) -> [DownloadedEpisode] {
        allEpisodes.filter { $0.animeId == animeId }
    }

    func removeAllDownloads(forAnimeId animeId: String) {
        let episodesToRemove = allEpisodes.filter { $0.animeId == animeId }
        for episode in episodesToRemove {
            removeDownload(episodeId: episode.episodeId)
        }
    }


    //#################################################################################
    // MARK: - Private Methods
    //#################################################################################

    private func performDownload(episodeId: String) async {
        guard let index = allEpisodes.firstIndex(where: { $0.episodeId == episodeId }) else {
            return
        }

        let episode = allEpisodes[index]

        // Update state to downloading
        allEpisodes[index].state = .downloading(progress: 0)
        refreshGroupedAnime(forAnimeId: allEpisodes[index].animeId)
        saveDownloads()

        do {
            try Task.checkCancellation()

            // Step 1: Extract the actual video URL from the source
            guard let sourceManager else {
                throw DownloadError.sourceManagerNotAvailable
            }

            Log.debug(.downloads, "Extracting video URL for episode: \(episodeId)")
            let playbackInfo = try await sourceManager.getVideoSources(sourceId: episode.sourceId,
                                                                        episodeId: episode.episodeId,
                                                                        url: episode.sourceURL)

            guard let videoSource = playbackInfo.sources.first else {
                throw DownloadError.noVideoSourceFound
            }

            Log.debug(.downloads, "Found video source: \(videoSource.url)")

            try Task.checkCancellation()

            // Step 2: Create the destination file path
            let animeDirectory = downloadsDirectory.appendingPathComponent("\(episode.animeId)")
            try fileManager.createDirectory(at: animeDirectory, withIntermediateDirectories: true)

            let fileName = "\(episode.episodeNumber.replacingOccurrences(of: "/", with: "-")).mp4"
            let destinationURL = animeDirectory.appendingPathComponent(fileName)

            // Remove existing file if present
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }

            // Step 3: Download the video file
            Log.debug(.downloads, "Downloading to: \(destinationURL.path)")
            try await downloadFile(from: videoSource.url,
                                   to: destinationURL,
                                   headers: videoSource.headers,
                                   episodeId: episodeId)

            try Task.checkCancellation()

            // Step 4: Mark as completed and set local file path
            if let currentIndex = allEpisodes.firstIndex(where: { $0.episodeId == episodeId }) {
                allEpisodes[currentIndex].state = .completed
                allEpisodes[currentIndex].completedAt = Date()
                allEpisodes[currentIndex].localFilePath = destinationURL.path
                refreshGroupedAnime(forAnimeId: allEpisodes[currentIndex].animeId)
                saveDownloads()
                Log.info(.downloads, "Download completed: \(destinationURL.path)")
            }
        } catch is CancellationError {
            Log.debug(.downloads, "Download cancelled: \(episodeId)")
            // Already handled in cancelDownload
        } catch {
            Log.error(.downloads, "Download failed: \(error)")
            if let currentIndex = allEpisodes.firstIndex(where: { $0.episodeId == episodeId }) {
                allEpisodes[currentIndex].state = .failed(error: error.localizedDescription)
                refreshGroupedAnime(forAnimeId: allEpisodes[currentIndex].animeId)
                saveDownloads()
            }
        }

        downloadTasks.removeValue(forKey: episodeId)
    }

    private func downloadFile(from url: URL,
                              to destination: URL,
                              headers: [String: String]?,
                              episodeId: String) async throws {
        var request = URLRequest(url: url)
        headers?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }

        let (asyncBytes, response) = try await URLSession.shared.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw DownloadError.httpError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? -1)
        }

        let expectedLength = httpResponse.expectedContentLength
        var downloadedData = Data()
        downloadedData.reserveCapacity(expectedLength > 0 ? Int(expectedLength) : 1024 * 1024 * 100)

        var downloadedBytes: Int64 = 0

        for try await byte in asyncBytes {
            try Task.checkCancellation()
            downloadedData.append(byte)
            downloadedBytes += 1

            // Update progress every ~100KB
            if downloadedBytes % (100 * 1024) == 0 {
                let progress = expectedLength > 0 ? Double(downloadedBytes) / Double(expectedLength) : 0
                if let currentIndex = allEpisodes.firstIndex(where: { $0.episodeId == episodeId }) {
                    allEpisodes[currentIndex].state = .downloading(progress: min(progress, 0.99))
                    refreshGroupedAnime(forAnimeId: allEpisodes[currentIndex].animeId)
                }
            }
        }

        try downloadedData.write(to: destination)
    }

    private func updateGroupedAnime(animeId: String,
                                     title: String,
                                     coverURL: URL?,
                                     sourceId: String,
                                     sourceName: String) {
        if let index = downloadedAnime.firstIndex(where: { $0.id == animeId }) {
            downloadedAnime[index].episodes = allEpisodes.filter { $0.animeId == animeId }
        } else {
            let anime = DownloadedAnime(id: animeId,
                                         title: title,
                                         coverURL: coverURL,
                                         sourceId: sourceId,
                                         sourceName: sourceName,
                                         episodes: allEpisodes.filter { $0.animeId == animeId })
            downloadedAnime.append(anime)
        }
    }

    private func refreshGroupedAnime(forAnimeId animeId: String) {
        if let index = downloadedAnime.firstIndex(where: { $0.id == animeId }) {
            let episodes = allEpisodes.filter { $0.animeId == animeId }
            if episodes.isEmpty {
                downloadedAnime.remove(at: index)
            } else {
                downloadedAnime[index].episodes = episodes
            }
        }
    }

    private func loadDownloads() {
        // Load episodes
        if let episodesData = userDefaults.data(forKey: Constants.episodesStorageKey),
           let decodedEpisodes = try? JSONDecoder().decode([DownloadedEpisode].self, from: episodesData) {
            allEpisodes = decodedEpisodes
        }

        // Load anime metadata
        if let animeData = userDefaults.data(forKey: Constants.animeStorageKey),
           let decodedAnime = try? JSONDecoder().decode([DownloadedAnime].self, from: animeData) {
            // Restore anime with their episodes
            downloadedAnime = decodedAnime.compactMap { anime in
                let episodes = allEpisodes.filter { $0.animeId == anime.id }
                guard !episodes.isEmpty else { return nil }
                return DownloadedAnime(id: anime.id,
                                        title: anime.title,
                                        coverURL: anime.coverURL,
                                        sourceId: anime.sourceId,
                                        sourceName: anime.sourceName,
                                        episodes: episodes)
            }
        } else {
            // Fallback for legacy data without anime metadata
            let grouped = Dictionary(grouping: allEpisodes) { $0.animeId }
            downloadedAnime = grouped.compactMap { animeId, episodes in
                guard let first = episodes.first else { return nil }
                return DownloadedAnime(id: animeId,
                                        title: "Unknown",
                                        coverURL: nil,
                                        sourceId: first.sourceId,
                                        sourceName: first.sourceName,
                                        episodes: episodes)
            }
        }
    }

    private func saveDownloads() {
        // Save episodes
        if let episodesEncoded = try? JSONEncoder().encode(allEpisodes) {
            userDefaults.set(episodesEncoded, forKey: Constants.episodesStorageKey)
        }

        // Save anime metadata
        if let animeEncoded = try? JSONEncoder().encode(downloadedAnime) {
            userDefaults.set(animeEncoded, forKey: Constants.animeStorageKey)
        }
    }
}
