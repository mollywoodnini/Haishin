//
//  VideoPlayerViewModel.swift
//  Miru
//
//  Created by Miru on 25.01.26.
//

import AVFoundation
import Foundation

/// ViewModel for managing video playback of anime episodes.
@Observable
@MainActor
final class VideoPlayerViewModel {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    /// The episode being played.
    let episode: Episode

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

    private let sourceManager: SourceManaging


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new video player view model.
    /// - Parameters:
    ///   - episode: The episode to play.
    ///   - sourceId: The source ID to fetch streams from.
    ///   - sourceManager: The source manager for fetching video sources.
    init(episode: Episode,
         sourceId: String,
         sourceManager: SourceManaging) {
        self.episode = episode
        self.sourceId = sourceId
        self.sourceManager = sourceManager
    }


    //#################################################################################
    // MARK: - Public Methods
    //#################################################################################

    /// Loads the video streams for the episode and starts playback.
    func loadAndPlay() async {
        isLoading = true
        error = nil

        print("[VideoPlayerViewModel] Loading streams for episode \(episode.number)")

        do {
            // Fetch playback info from source
            let info = try await sourceManager.getVideoSources(sourceId: sourceId,
                                                                url: episode.url)
            playbackInfo = info

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

    /// Selects a video source and starts playback.
    /// - Parameter source: The video source to play.
    func selectSource(_ source: VideoSource) {
        selectedSource = source
        print("[VideoPlayerViewModel] Selected source: \(source.serverName) - \(source.quality ?? "default")")

        // Create AVPlayer with the source URL
        var request = URLRequest(url: source.url)

        // Add any required headers
        if let headers = source.headers {
            for (key, value) in headers {
                request.addValue(value, forHTTPHeaderField: key)
            }
        }

        let asset = AVURLAsset(url: source.url, options: source.headers.map { ["AVURLAssetHTTPHeaderFieldsKey": $0] })
        let playerItem = AVPlayerItem(asset: asset)

        if player == nil {
            player = AVPlayer(playerItem: playerItem)
        } else {
            player?.replaceCurrentItem(with: playerItem)
        }

        // Start playback
        player?.play()
        print("[VideoPlayerViewModel] Playback started")
    }

    /// Pauses playback.
    func pause() {
        player?.pause()
    }

    /// Resumes playback.
    func play() {
        player?.play()
    }

    /// Cleans up the player when done.
    func cleanup() {
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil
    }
}


//#################################################################################
// MARK: - VideoPlayerError
//#################################################################################

enum VideoPlayerError: LocalizedError {
    case noSourcesAvailable
    case streamLoadFailed

    var errorDescription: String? {
        switch self {
        case .noSourcesAvailable:
            return "No video sources available for this episode."
        case .streamLoadFailed:
            return "Failed to load video stream."
        }
    }
}
