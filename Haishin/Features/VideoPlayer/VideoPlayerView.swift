//
//  VideoPlayerView.swift
//  Miru
//
//  Created by Miru on 25.01.26.
//

import AVKit
import SwiftUI

/// Full-screen video player for anime episodes.
struct VideoPlayerView: View {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    @State private var viewModel: VideoPlayerViewModel
    @Environment(\.dismiss) private var dismiss

    private let animeTitle: String
    private let animeCoverURL: URL?


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new video player view with an existing view model.
    /// - Parameter viewModel: The view model to use.
    init(viewModel: VideoPlayerViewModel) {
        self.animeTitle = viewModel.animeTitle
        self.animeCoverURL = viewModel.animeCoverURL
        self._viewModel = State(initialValue: viewModel)
    }

    /// Creates a new video player view.
    /// - Parameters:
    ///   - episode: The episode to play.
    ///   - animeId: The anime ID for progress tracking.
    ///   - animeTitle: The title of the anime.
    ///   - animeCoverURL: The cover URL of the anime.
    ///   - sourceId: The source ID to fetch streams from.
    ///   - sourceManager: The source manager for fetching video sources.
    ///   - watchProgressService: The service for tracking watch progress.
    init(episode: Episode,
         animeId: Int,
         animeTitle: String,
         animeCoverURL: URL?,
         sourceId: String,
         sourceManager: SourceManaging,
         watchProgressService: WatchProgressServiceProtocol) {
        self.animeTitle = animeTitle
        self.animeCoverURL = animeCoverURL
        self._viewModel = State(initialValue: VideoPlayerViewModel(episode: episode,
                                                                   animeId: animeId,
                                                                   animeTitle: animeTitle,
                                                                   animeCoverURL: animeCoverURL,
                                                                   sourceId: sourceId,
                                                                   sourceManager: sourceManager,
                                                                   watchProgressService: watchProgressService))
    }


    //#################################################################################
    // MARK: - Body
    //#################################################################################

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            if viewModel.isLoading {
                loadingView
            } else if let error = viewModel.error {
                errorView(error: error)
            } else if let player = viewModel.player {
                videoPlayerView(player: player)
            } else {
                // Initial state before loading
                loadingView
            }
        }
        .navigationBarHidden(true)
        .statusBarHidden(true)
        .task {
            await viewModel.loadAndPlay()
        }
        .onDisappear {
            viewModel.cleanup()
        }
    }


    //#################################################################################
    // MARK: - Loading View
    //#################################################################################

    private var loadingView: some View {
        VStack(spacing: .spacingM) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.white)

            Text("Loading Episode \(viewModel.episode.number)...")
                .font(.headline)
                .foregroundStyle(.white)
        }
    }


    //#################################################################################
    // MARK: - Error View
    //#################################################################################

    private func errorView(error: Error) -> some View {
        VStack(spacing: .spacingM) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.yellow)

            Text("Playback Error")
                .font(.headline)
                .foregroundStyle(.white)

            Text(error.localizedDescription)
                .font(.subheadline)
                .foregroundStyle(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, .spacingL)

            HStack(spacing: .spacingS) {
                Button("Close") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .tint(.white)

                Button("Retry") {
                    Task {
                        await viewModel.loadAndPlay()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }


    //#################################################################################
    // MARK: - Video Player View
    //#################################################################################

    private func videoPlayerView(player: AVPlayer) -> some View {
        ZStack {
            VideoPlayer(player: player)
                .ignoresSafeArea()

            // Overlay with dismiss button
            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundStyle(.white.opacity(0.8))
                            .padding(.spacingM)
                    }

                    Spacer()

                    // Episode info
                    VStack(alignment: .trailing) {
                        Text(animeTitle)
                            .font(.headline)
                            .foregroundStyle(.white.opacity(0.7))

                        Text("Episode \(viewModel.episode.number)")
                            .font(.subheadline)
                            .foregroundStyle(.white)

                        if let title = viewModel.episode.title,
                           title != "\(viewModel.episode.number)" {
                            Text(title)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                    .padding(.spacingM)
                }

                Spacer()
            }
        }
    }
}
