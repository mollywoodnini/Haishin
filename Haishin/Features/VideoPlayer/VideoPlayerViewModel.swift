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
import MediaPlayer

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

    /// Whether this is playing a downloaded file.
    let isOfflineMode: Bool

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

    /// Available subtitle tracks.
    private(set) var availableSubtitles: [Subtitle] = []

    /// Currently selected subtitle track (nil = off).
    private(set) var selectedSubtitle: Subtitle?

    /// The subtitle renderer for displaying external subtitles.
    let subtitleRenderer = SubtitleRenderer()

    /// Callback when episode playback finishes (for external handling like auto-advance).
    var onEpisodeFinished: ((Episode) -> Void)?

    private let sourceManager: SourceManaging?
    private let watchProgressService: WatchProgressServiceProtocol
    private var allSources: [VideoSource] = []
    private var currentSourceIndex = 0
    private var playerItemObserver: AnyCancellable?
    private var playerItemFailedObserver: NSObjectProtocol?
    private var playbackEndObserver: NSObjectProtocol?
    private var timeObserver: Any?
    private var lastSavedTime: TimeInterval = 0
    private var nowPlayingArtworkTask: Task<Void, Never>?


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
    ///   - sourceManager: The source manager for fetching video sources (nil for offline mode).
    ///   - watchProgressService: The service for persisting watch progress.
    ///   - isOfflineMode: Whether this is playing a downloaded file.
    init(episode: Episode,
         animeId: Int,
         animeTitle: String,
         animeCoverURL: URL?,
         sourceId: String,
         sourceManager: SourceManaging?,
         watchProgressService: WatchProgressServiceProtocol,
         isOfflineMode: Bool = false) {
        self.episode = episode
        self.animeId = animeId
        self.animeTitle = animeTitle
        self.animeCoverURL = animeCoverURL
        self.sourceId = sourceId
        self.sourceManager = sourceManager
        self.watchProgressService = watchProgressService
        self.isOfflineMode = isOfflineMode
    }


    //#################################################################################
    // MARK: - Public Methods
    //#################################################################################

    /// Loads the video streams for the episode and starts playback.
    func loadAndPlay() async {
        isLoading = true
        error = nil
        currentSourceIndex = 0

        // Configure audio session to play sound even when device is muted
        configureAudioSession()

        print("[VideoPlayerViewModel] Loading streams for episode \(episode.number)")

        // Restore previous progress if available
        if let savedProgress = watchProgressService.getProgress(animeId: animeId, episodeId: episode.id) {
            currentTime = savedProgress.currentTime
            duration = savedProgress.duration
            currentProgress = savedProgress.progress
            print("[VideoPlayerViewModel] Restored progress: \(Int(savedProgress.progress * 100))%")
        }

        if isOfflineMode {
            await loadOfflineVideo()
        } else {
            await loadOnlineVideo()
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

    /// Selects a subtitle track for playback.
    /// - Parameter subtitle: The subtitle to select, or nil to turn off subtitles.
    func selectSubtitle(_ subtitle: Subtitle?) {
        selectedSubtitle = subtitle

        if let subtitle {
            print("[VideoPlayerViewModel] Selected subtitle: \(subtitle.label)")
            subtitleRenderer.load(from: subtitle.url)
        } else {
            print("[VideoPlayerViewModel] Subtitles turned off")
            subtitleRenderer.clear()
        }
    }

    /// Cleans up the player and saves progress when done.
    func cleanup() {
        saveProgress()
        removeTimeObserver()
        removePlayerItemObservers()
        removePlaybackEndObserver()
        clearRemoteCommandCenter()
        clearNowPlayingInfo()
        subtitleRenderer.clear()
        nowPlayingArtworkTask?.cancel()
        nowPlayingArtworkTask = nil
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil
    }


    //#################################################################################
    // MARK: - Private Methods
    //#################################################################################

    private func configureAudioSession() {
        #if os(iOS)
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .moviePlayback)
            try audioSession.setActive(true)
            print("[VideoPlayerViewModel] Audio session configured for playback")
        } catch {
            print("[VideoPlayerViewModel] Failed to configure audio session: \(error)")
        }
        #endif
    }

    private func loadOnlineVideo() async {
        guard let sourceManager else {
            error = VideoPlayerError.noSourcesAvailable
            isLoading = false
            return
        }

        do {
            // Fetch playback info from source
            let info = try await sourceManager.getVideoSources(sourceId: sourceId,
                                                                episodeId: episode.id,
                                                                url: episode.url)
            playbackInfo = info
            allSources = info.sources
            availableSubtitles = info.subtitles

            print("[VideoPlayerViewModel] Got \(info.sources.count) video source(s) and \(info.subtitles.count) subtitle(s)")

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

    private func loadOfflineVideo() async {
        // For offline mode, the episode URL contains the local file path
        let fileURL: URL
        if episode.url.hasPrefix("/") {
            // It's an absolute file path
            fileURL = URL(fileURLWithPath: episode.url)
        } else if let url = URL(string: episode.url), url.isFileURL {
            fileURL = url
        } else {
            print("[VideoPlayerViewModel] Invalid offline file path: \(episode.url)")
            error = VideoPlayerError.noSourcesAvailable
            isLoading = false
            return
        }

        // Verify the file exists
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("[VideoPlayerViewModel] Offline file not found: \(fileURL.path)")
            error = VideoPlayerError.noSourcesAvailable
            isLoading = false
            return
        }

        print("[VideoPlayerViewModel] Playing offline file: \(fileURL.path)")

        // Create a VideoSource for the local file
        let localSource = VideoSource(id: "local-\(episode.id)",
                                       serverName: "Local",
                                       quality: "Downloaded",
                                       url: fileURL,
                                       headers: nil,
                                       requiresExtraction: false)
        allSources = [localSource]
        selectSource(localSource)
        isLoading = false
    }

    private func selectSource(_ source: VideoSource) {
        selectedSource = source
        print("[VideoPlayerViewModel] Selected source: \(source.serverName) - \(source.quality ?? "default")")

        let asset = AVURLAsset(url: source.url,
                               options: source.headers.map { ["AVURLAssetHTTPHeaderFieldsKey": $0] })
        let playerItem = AVPlayerItem(asset: asset)

        // Observe player item for failures
        observePlayerItem(playerItem)

        // Observe playback completion for auto-advance
        setupPlaybackEndObserver(playerItem)

        if player == nil {
            player = AVPlayer(playerItem: playerItem)
            // Setup remote commands once when player is created
            setupRemoteCommandCenter()
        } else {
            player?.replaceCurrentItem(with: playerItem)
        }

        // Setup time observer for progress tracking
        setupTimeObserver()

        // Setup Now Playing info for lock screen / control center
        setupNowPlayingInfo()

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

        // Update subtitle display
        subtitleRenderer.update(for: currentSeconds)

        // Save progress periodically (every N seconds)
        if abs(currentSeconds - lastSavedTime) >= Constants.progressSaveInterval {
            saveProgress()
            updateNowPlayingTime()
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

    private func setupPlaybackEndObserver(_ playerItem: AVPlayerItem) {
        removePlaybackEndObserver()

        playbackEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                self?.handlePlaybackEnd()
            }
        }
    }

    private func removePlaybackEndObserver() {
        if let observer = playbackEndObserver {
            NotificationCenter.default.removeObserver(observer)
            playbackEndObserver = nil
        }
    }

    private func handlePlaybackEnd() {
        print("[VideoPlayerViewModel] Episode \(episode.number) finished playing")

        // Save final progress
        saveProgress()

        // Notify external listener - parent handles what happens next
        onEpisodeFinished?(episode)
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

    private func setupRemoteCommandCenter() {
        #if os(iOS)
        let commandCenter = MPRemoteCommandCenter.shared()

        // Play command
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.player?.play()
            return .success
        }

        // Pause command
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.player?.pause()
            return .success
        }

        // Toggle play/pause command
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let self, let player = self.player else { return .commandFailed }
            if player.timeControlStatus == .playing {
                player.pause()
            } else {
                player.play()
            }
            return .success
        }

        // Skip forward command (15 seconds)
        commandCenter.skipForwardCommand.isEnabled = true
        commandCenter.skipForwardCommand.preferredIntervals = [15]
        commandCenter.skipForwardCommand.addTarget { [weak self] event in
            guard let self,
                  let player = self.player,
                  let skipEvent = event as? MPSkipIntervalCommandEvent else { return .commandFailed }
            let currentTime = player.currentTime()
            let newTime = CMTimeAdd(currentTime, CMTime(seconds: skipEvent.interval, preferredTimescale: 600))
            player.seek(to: newTime)
            return .success
        }

        // Skip backward command (15 seconds)
        commandCenter.skipBackwardCommand.isEnabled = true
        commandCenter.skipBackwardCommand.preferredIntervals = [15]
        commandCenter.skipBackwardCommand.addTarget { [weak self] event in
            guard let self,
                  let player = self.player,
                  let skipEvent = event as? MPSkipIntervalCommandEvent else { return .commandFailed }
            let currentTime = player.currentTime()
            let newTime = CMTimeSubtract(currentTime, CMTime(seconds: skipEvent.interval, preferredTimescale: 600))
            player.seek(to: newTime)
            return .success
        }

        // Seek command (scrubbing)
        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self,
                  let player = self.player,
                  let positionEvent = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            let newTime = CMTime(seconds: positionEvent.positionTime, preferredTimescale: 600)
            player.seek(to: newTime)
            return .success
        }

        print("[VideoPlayerViewModel] Remote command center configured")
        #endif
    }

    private func clearRemoteCommandCenter() {
        #if os(iOS)
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.removeTarget(nil)
        commandCenter.pauseCommand.removeTarget(nil)
        commandCenter.togglePlayPauseCommand.removeTarget(nil)
        commandCenter.skipForwardCommand.removeTarget(nil)
        commandCenter.skipBackwardCommand.removeTarget(nil)
        commandCenter.changePlaybackPositionCommand.removeTarget(nil)
        print("[VideoPlayerViewModel] Remote command center cleared")
        #endif
    }

    private func setupNowPlayingInfo() {
        #if os(iOS)
        var nowPlayingInfo = [String: Any]()

        // Title: Episode title or "Episode X"
        let episodeTitle = episode.title ?? "Episode \(episode.number)"
        nowPlayingInfo[MPMediaItemPropertyTitle] = episodeTitle

        // Album/Artist: Anime title
        nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = animeTitle
        nowPlayingInfo[MPMediaItemPropertyArtist] = animeTitle

        // Duration and current time
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = player?.rate ?? 0

        // Media type
        nowPlayingInfo[MPNowPlayingInfoPropertyMediaType] = MPNowPlayingInfoMediaType.video.rawValue

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo

        // Load artwork asynchronously
        loadNowPlayingArtwork()

        print("[VideoPlayerViewModel] Now Playing info set: \(animeTitle) - \(episodeTitle)")
        #endif
    }

    private func loadNowPlayingArtwork() {
        #if os(iOS)
        nowPlayingArtworkTask?.cancel()

        guard let coverURL = animeCoverURL else { return }

        nowPlayingArtworkTask = Task { [weak self] in
            do {
                let (data, _) = try await URLSession.shared.data(from: coverURL)
                guard !Task.isCancelled else { return }

                if let image = UIImage(data: data) {
                    let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }

                    await MainActor.run {
                        guard !Task.isCancelled else { return }
                        var nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
                        nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
                        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
                        print("[VideoPlayerViewModel] Now Playing artwork loaded")
                    }
                }
            } catch {
                print("[VideoPlayerViewModel] Failed to load artwork: \(error)")
            }
        }
        #endif
    }

    private func updateNowPlayingTime() {
        #if os(iOS)
        guard var nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }

        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = player?.rate ?? 0

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        #endif
    }

    private func clearNowPlayingInfo() {
        #if os(iOS)
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        print("[VideoPlayerViewModel] Now Playing info cleared")
        #endif
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
