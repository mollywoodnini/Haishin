//
//  VideoPlayerViewModel.swift
//  Miru
//
//  Created by Miru on 25.01.26.
//

import AVFoundation
import Combine
import CoreMedia
import Foundation

/// ViewModel for managing video playback of anime episodes.
@Observable
@MainActor
final class VideoPlayerViewModel {

    //#################################################################################
    // MARK: - Constants
    //#################################################################################

    private struct Constants {
        static let progressSaveInterval: TimeInterval = 5.0
    }


    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    /// The episode being played.
    let episode: Episode

    /// The anime ID for progress tracking.
    let animeId: Int

    /// The anime title for recents tracking.
    let animeTitle: String

    /// The anime cover URL for recents tracking.
    let animeCoverURL: URL?

    /// The source ID to fetch streams from.
    let sourceId: String

    /// The current playback info with available streams.
    private(set) var playbackInfo: PlaybackInfo?

    /// The currently selected video source.
    private(set) var selectedSource: VideoSource?

    /// The AVPlayer instance for video playback.
    private(set) var player: AVPlayer?

    /// Whether the stream is currently loading.
    private(set) var isLoading = false

    /// The last error that occurred.
    private(set) var error: Error?

    /// Current playback progress (0.0 to 1.0).
    private(set) var currentProgress: Double = 0

    /// Current playback time in seconds.
    private(set) var currentTime: TimeInterval = 0

    /// Total duration in seconds.
    private(set) var duration: TimeInterval = 0

    private let sourceManager: SourceManaging
    private let watchProgressService: WatchProgressServiceProtocol
    private var allSources: [VideoSource] = []
    private var currentSourceIndex = 0
    private var playerItemObserver: AnyCancellable?
    private var playerItemFailedObserver: NSObjectProtocol?
    private var timeObserver: Any?
    private var lastSavedTime: TimeInterval = 0


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new video player view model.
    /// - Parameters:
    ///   - episode: The episode to play.
    ///   - animeId: The anime ID for progress tracking.
    ///   - animeTitle: The anime title for recents tracking.
    ///   - animeCoverURL: The anime cover URL for recents tracking.
    ///   - sourceId: The source ID to fetch streams from.
    ///   - sourceManager: The source manager for fetching video sources.
    ///   - watchProgressService: The service for persisting watch progress.
    init(episode: Episode,
         animeId: Int,
         animeTitle: String,
         animeCoverURL: URL?,
         sourceId: String,
         sourceManager: SourceManaging,
         watchProgressService: WatchProgressServiceProtocol = WatchProgressService.shared) {
        self.episode = episode
        self.animeId = animeId
        self.animeTitle = animeTitle
        self.animeCoverURL = animeCoverURL
        self.sourceId = sourceId
        self.sourceManager = sourceManager
        self.watchProgressService = watchProgressService
    }


    //#################################################################################
    // MARK: - Public Methods
    //#################################################################################

    /// Loads the video streams for the episode and starts playback.
    func loadAndPlay() async {
        isLoading = true
        error = nil
        currentSourceIndex = 0

        print("[VideoPlayerViewModel] Loading streams for episode \(episode.number)")

        // Restore previous progress if available
        if let savedProgress = watchProgressService.getProgress(animeId: animeId, episodeId: episode.id) {
            currentTime = savedProgress.currentTime
            duration = savedProgress.duration
            currentProgress = savedProgress.progress
            print("[VideoPlayerViewModel] Restored progress: \(Int(savedProgress.progress * 100))%")
        }

        do {
            // Fetch playback info from source
            let info = try await sourceManager.getVideoSources(sourceId: sourceId,
                                                                episodeId: episode.id,
                                                                url: episode.url)
            playbackInfo = info
            allSources = info.sources

            print("[VideoPlayerViewModel] Got \(info.sources.count) video source(s)")

            // Select the first available source
            guard let firstSource = info.sources.first else {
                throw VideoPlayerError.noSourcesAvailable
            }

            selectSource(firstSource)
            isLoading = false
        } catch {
            print("[VideoPlayerViewModel] Error loading streams: \(error)")
            self.error = error
            isLoading = false
        }
    }

    /// Pauses playback.
    func pause() {
        player?.pause()
    }

    /// Resumes playback.
    func play() {
        player?.play()
    }

    /// Cleans up the player and saves progress when done.
    func cleanup() {
        saveProgress()
        removeTimeObserver()
        removePlayerItemObservers()
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil
    }


    //#################################################################################
    // MARK: - Private Methods
    //#################################################################################

    private func selectSource(_ source: VideoSource) {
        selectedSource = source
        print("[VideoPlayerViewModel] Selected source: \(source.serverName) - \(source.quality ?? "default")")

        let asset = AVURLAsset(url: source.url,
                               options: source.headers.map { ["AVURLAssetHTTPHeaderFieldsKey": $0] })
        let playerItem = AVPlayerItem(asset: asset)

        // Observe player item for failures
        observePlayerItem(playerItem)

        if player == nil {
            player = AVPlayer(playerItem: playerItem)
        } else {
            player?.replaceCurrentItem(with: playerItem)
        }

        // Setup time observer for progress tracking
        setupTimeObserver()

        // Seek to saved position if we have one
        if currentTime > 0 {
            let seekTime = CMTime(seconds: currentTime, preferredTimescale: 600)
            player?.seek(to: seekTime) { [weak self] _ in
                self?.player?.play()
                print("[VideoPlayerViewModel] Resumed playback at \(Int(self?.currentTime ?? 0))s")
            }
        } else {
            player?.play()
        }

        print("[VideoPlayerViewModel] Playback started")
    }

    private func setupTimeObserver() {
        removeTimeObserver()

        guard let player else { return }

        // Observe time every 0.5 seconds
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor [weak self] in
                self?.handleTimeUpdate(time)
            }
        }
    }

    private func removeTimeObserver() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
    }

    private func handleTimeUpdate(_ time: CMTime) {
        guard let player,
              let currentItem = player.currentItem else { return }

        let currentSeconds = time.seconds
        let durationSeconds = currentItem.duration.seconds

        // Skip if duration is not valid yet
        guard durationSeconds.isFinite && durationSeconds > 0 else { return }

        currentTime = currentSeconds
        duration = durationSeconds
        currentProgress = min(currentSeconds / durationSeconds, 1.0)

        // Save progress periodically (every N seconds)
        if abs(currentSeconds - lastSavedTime) >= Constants.progressSaveInterval {
            saveProgress()
            lastSavedTime = currentSeconds
        }
    }

    private func saveProgress() {
        guard duration > 0 else {
            print("[VideoPlayerViewModel] Skipping progress save - duration is 0")
            return
        }

        let progress = WatchProgress(animeId: animeId,
                                     episodeId: episode.id,
                                     episodeNumber: episode.number,
                                     currentTime: currentTime,
                                     duration: duration,
                                     lastUpdated: Date())

        watchProgressService.saveProgress(progress)

        // Also update recents tracking
        watchProgressService.updateRecentAnime(id: animeId,
                                               title: animeTitle,
                                               coverURL: animeCoverURL,
                                               episodeNumber: episode.number)

        print("[VideoPlayerViewModel] Saved progress: \(Int(currentProgress * 100))% and updated recents for '\(animeTitle)'")
    }

    private func observePlayerItem(_ playerItem: AVPlayerItem) {
        removePlayerItemObservers()

        // Observe status changes using Combine
        playerItemObserver = playerItem.publisher(for: \.status)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                if status == .failed {
                    self?.handlePlaybackFailure(playerItem.error)
                }
            }

        // Observe failed to play to end notification
        playerItemFailedObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] notification in
            let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error
            guard let self else { return }
            Task { @MainActor [weak self] in
                self?.handlePlaybackFailure(error)
            }
        }
    }

    private func removePlayerItemObservers() {
        playerItemObserver?.cancel()
        playerItemObserver = nil

        if let observer = playerItemFailedObserver {
            NotificationCenter.default.removeObserver(observer)
            playerItemFailedObserver = nil
        }
    }

    private func handlePlaybackFailure(_ playbackError: Error?) {
        print("[VideoPlayerViewModel] Playback failed: \(playbackError?.localizedDescription ?? "Unknown error")")
        tryNextSource()
    }

    private func tryNextSource() {
        currentSourceIndex += 1

        guard currentSourceIndex < allSources.count else {
            print("[VideoPlayerViewModel] All sources exhausted, no more fallbacks available")
            error = VideoPlayerError.allSourcesFailed
            return
        }

        let nextSource = allSources[currentSourceIndex]
        print("[VideoPlayerViewModel] Trying fallback source \(currentSourceIndex + 1)/\(allSources.count): \(nextSource.serverName)")
        selectSource(nextSource)
    }
}


//#################################################################################
// MARK: - VideoPlayerError
//#################################################################################

enum VideoPlayerError: LocalizedError {
    case noSourcesAvailable
    case streamLoadFailed
    case allSourcesFailed

    var errorDescription: String? {
        switch self {
        case .noSourcesAvailable:
            return "No video sources available for this episode."
        case .streamLoadFailed:
            return "Failed to load video stream."
        case .allSourcesFailed:
            return "All video sources failed to play. Please try a different source."
        }
    }
}
