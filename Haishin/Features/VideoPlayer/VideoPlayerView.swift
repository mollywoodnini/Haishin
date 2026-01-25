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


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new video player view with an existing view model.
    /// - Parameter viewModel: The view model to use.
    init(viewModel: VideoPlayerViewModel) {
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
                AVPlayerViewControllerRepresentable(player: player, onDismiss: {
                    dismiss()
                })
                .ignoresSafeArea()
            } else {
                // Initial state before loading
                loadingView
            }
        }
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
        ZStack(alignment: .topLeading) {
            VStack(spacing: .spacingM) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)

                Text("Loading Episode \(viewModel.episode.number)...")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.spacingM)
            }
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
}


//#################################################################################
// MARK: - AVPlayerViewControllerRepresentable
//#################################################################################

/// UIViewControllerRepresentable wrapper for AVPlayerViewController.
/// This provides native video controls with a built-in dismiss button.
struct AVPlayerViewControllerRepresentable: UIViewControllerRepresentable {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    private let player: AVPlayer
    private let onDismiss: () -> Void


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new AVPlayerViewController representable.
    /// - Parameters:
    ///   - player: The AVPlayer instance to use.
    ///   - onDismiss: Callback when the player is dismissed.
    init(player: AVPlayer, onDismiss: @escaping () -> Void) {
        self.player = player
        self.onDismiss = onDismiss
    }


    //#################################################################################
    // MARK: - UIViewControllerRepresentable
    //#################################################################################

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.delegate = context.coordinator
        controller.allowsPictureInPicturePlayback = true
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        // No updates needed
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onDismiss: onDismiss)
    }


    //#################################################################################
    // MARK: - Coordinator
    //#################################################################################

    class Coordinator: NSObject, AVPlayerViewControllerDelegate {
        private let onDismiss: () -> Void

        init(onDismiss: @escaping () -> Void) {
            self.onDismiss = onDismiss
        }

        func playerViewController(_ playerViewController: AVPlayerViewController,
                                  willEndFullScreenPresentationWithAnimationCoordinator coordinator: any UIViewControllerTransitionCoordinator) {
            coordinator.animate(alongsideTransition: nil) { _ in
                self.onDismiss()
            }
        }
    }
}
