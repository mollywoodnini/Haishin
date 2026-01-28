//
//  DownloadService.swift
//  Haishin
//
//  Created by Tan Nghia La on 25.01.26.
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

    /// The video ID this episode belongs to.
    let videoId: String

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
// MARK: - DownloadedVideo
//#################################################################################

/// Represents a video with downloaded episodes.
struct DownloadedVideo: VideoProtocol, Codable, Equatable {

    /// The video ID.
    let id: String

    /// The video title.
    let title: String

    /// URL to the cover image.
    let coverURL: URL?

    /// The source ID used for downloads.
    let sourceId: String

    /// The source name for display.
    let sourceName: String

    /// All downloaded episodes for this video.
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
    /// All downloaded videos.
    var downloadedVideo: [DownloadedVideo] { get }

    /// All active downloads.
    var activeDownloads: [DownloadedEpisode] { get }

    /// Total count of downloaded episodes.
    var totalDownloadsCount: Int { get }

    /// Sets the source manager for video extraction.
    func setSourceManager(_ sourceManager: SourceManaging)

    /// Starts downloading an episode.
    func startDownload(videoId: String,
                       videoTitle: String,
                       videoCoverURL: URL?,
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

    /// Gets all downloads for a video.
    func getDownloads(forVideoId videoId: String) -> [DownloadedEpisode]

    /// Removes all downloads for a video.
    func removeAllDownloads(forVideoId videoId: String)
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
        static let animeStorageKey = "downloadedVideoMetadata"
        static let downloadsDirectory = "Downloads"
    }


    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    /// Shared instance for app-wide use.
    static let shared = DownloadService()

    /// All downloaded videos grouped.
    private(set) var downloadedVideo: [DownloadedVideo] = []

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

    func startDownload(videoId: String,
                       videoTitle: String,
                       videoCoverURL: URL?,
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
                                                   videoId: videoId,
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
        updateGroupedVideo(videoId: videoId,
                           title: videoTitle,
                           coverURL: videoCoverURL,
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
            let videoId = allEpisodes[index].videoId
            allEpisodes.remove(at: index)
            refreshGroupedVideo(forVideoId: videoId)
            saveDownloads()
        }
    }

    func removeDownload(episodeId: String) {
        downloadTasks[episodeId]?.cancel()
        downloadTasks.removeValue(forKey: episodeId)

        if let index = allEpisodes.firstIndex(where: { $0.episodeId == episodeId }) {
            let episode = allEpisodes[index]
            let videoId = episode.videoId

            // Delete local file if exists
            if let filePath = episode.localFilePath {
                try? fileManager.removeItem(atPath: filePath)
            }

            allEpisodes.remove(at: index)
            refreshGroupedVideo(forVideoId: videoId)
            saveDownloads()
        }
    }

    func getDownloadState(episodeId: String) -> DownloadState? {
        allEpisodes.first { $0.episodeId == episodeId }?.state
    }

    func getDownloads(forVideoId videoId: String) -> [DownloadedEpisode] {
        allEpisodes.filter { $0.videoId == videoId }
    }

    func removeAllDownloads(forVideoId videoId: String) {
        let episodesToRemove = allEpisodes.filter { $0.videoId == videoId }
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
        refreshGroupedVideo(forVideoId: allEpisodes[index].videoId)
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
            let videoDirectory = downloadsDirectory.appendingPathComponent("\(episode.videoId)")
            try fileManager.createDirectory(at: videoDirectory, withIntermediateDirectories: true)

            let fileName = "\(episode.episodeNumber.replacingOccurrences(of: "/", with: "-")).mp4"
            let destinationURL = videoDirectory.appendingPathComponent(fileName)

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
                refreshGroupedVideo(forVideoId: allEpisodes[currentIndex].videoId)
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
                refreshGroupedVideo(forVideoId: allEpisodes[currentIndex].videoId)
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
                    refreshGroupedVideo(forVideoId: allEpisodes[currentIndex].videoId)
                }
            }
        }

        try downloadedData.write(to: destination)
    }

    private func updateGroupedVideo(videoId: String,
                                     title: String,
                                     coverURL: URL?,
                                     sourceId: String,
                                     sourceName: String) {
        if let index = downloadedVideo.firstIndex(where: { $0.id == videoId }) {
            downloadedVideo[index].episodes = allEpisodes.filter { $0.videoId == videoId }
        } else {
            let video = DownloadedVideo(id: videoId,
                                         title: title,
                                         coverURL: coverURL,
                                         sourceId: sourceId,
                                         sourceName: sourceName,
                                         episodes: allEpisodes.filter { $0.videoId == videoId })
            downloadedVideo.append(video)
        }
    }

    private func refreshGroupedVideo(forVideoId videoId: String) {
        if let index = downloadedVideo.firstIndex(where: { $0.id == videoId }) {
            let episodes = allEpisodes.filter { $0.videoId == videoId }
            if episodes.isEmpty {
                downloadedVideo.remove(at: index)
            } else {
                downloadedVideo[index].episodes = episodes
            }
        }
    }

    private func loadDownloads() {
        // Load episodes
        if let episodesData = userDefaults.data(forKey: Constants.episodesStorageKey),
           let decodedEpisodes = try? JSONDecoder().decode([DownloadedEpisode].self, from: episodesData) {
            allEpisodes = decodedEpisodes
        }

        // Load video metadata
        if let videoData = userDefaults.data(forKey: Constants.animeStorageKey),
           let decodedVideo = try? JSONDecoder().decode([DownloadedVideo].self, from: videoData) {
            // Restore videos with their episodes
            downloadedVideo = decodedVideo.compactMap { video in
                let episodes = allEpisodes.filter { $0.videoId == video.id }
                guard !episodes.isEmpty else { return nil }
                return DownloadedVideo(id: video.id,
                                        title: video.title,
                                        coverURL: video.coverURL,
                                        sourceId: video.sourceId,
                                        sourceName: video.sourceName,
                                        episodes: episodes)
            }
        } else {
            // Fallback for legacy data without video metadata
            let grouped = Dictionary(grouping: allEpisodes) { $0.videoId }
            downloadedVideo = grouped.compactMap { videoId, episodes in
                guard let first = episodes.first else { return nil }
                return DownloadedVideo(id: videoId,
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

        // Save video metadata
        if let videoEncoded = try? JSONEncoder().encode(downloadedVideo) {
            userDefaults.set(videoEncoded, forKey: Constants.animeStorageKey)
        }
    }
}
