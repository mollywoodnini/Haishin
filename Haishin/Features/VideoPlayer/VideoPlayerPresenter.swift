//
//  VideoPlayerPresenter.swift
//  Haishin
//
//  Created by OpenCode on 26.01.26.
//

import AVKit
import SwiftUI

#if os(iOS)

/// Handles UIKit-based presentation of AVPlayerViewController for proper PiP support.
/// AVPlayerViewController must be presented directly via UIKit (not embedded in SwiftUI)
/// for Picture-in-Picture to work correctly.
@MainActor
final class VideoPlayerPresenter: NSObject {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    /// Shared instance for app-wide video player presentation.
    static let shared = VideoPlayerPresenter()

    private(set) var playerViewController: AVPlayerViewController?
    private(set) var viewModel: VideoPlayerViewModel?
    private(set) var isInPictureInPicture = false
    private(set) var isLoading = false
    private var loadingTask: Task<Void, Never>?
    private var onDismiss: (() -> Void)?
    private var onEpisodeFinished: ((Episode) -> Void)?


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    private override init() {
        super.init()
    }


    //#################################################################################
    // MARK: - Public Methods
    //#################################################################################

    /// Presents the video player for the given view model.
    /// - Parameters:
    ///   - viewModel: The video player view model.
    ///   - onDismiss: Callback when the player is dismissed.
    ///   - onEpisodeFinished: Callback when the episode finishes playing.
    ///   - onLoadingStateChanged: Callback when loading state changes (isLoading, error).
    func present(viewModel: VideoPlayerViewModel,
                 onDismiss: (() -> Void)? = nil,
                 onEpisodeFinished: ((Episode) -> Void)? = nil,
                 onLoadingStateChanged: ((_ isLoading: Bool, _ error: Error?) -> Void)? = nil) {
        // If already presenting, dismiss first
        if playerViewController != nil {
            dismiss(animated: false)
        }

        // Cancel any existing loading task
        loadingTask?.cancel()

        self.viewModel = viewModel
        self.onDismiss = onDismiss
        self.onEpisodeFinished = onEpisodeFinished
        self.isLoading = true

        // Notify that loading started
        onLoadingStateChanged?(true, nil)

        // Set up the episode finished callback on the view model
        viewModel.onEpisodeFinished = { [weak self] episode in
            self?.onEpisodeFinished?(episode)
        }

        // Start loading the video
        loadingTask = Task {
            await viewModel.loadAndPlay()

            // Check if cancelled
            guard !Task.isCancelled else {
                await MainActor.run {
                    self.isLoading = false
                    onLoadingStateChanged?(false, nil)
                }
                return
            }

            guard let player = viewModel.player else {
                Log.warning(.playback, "No player available after loading")
                await MainActor.run {
                    self.isLoading = false
                    onLoadingStateChanged?(false, viewModel.error ?? VideoPlayerError.noSourcesAvailable)
                }
                return
            }

            // Wait for player to reach readyToPlay status
            await waitForPlayerReady(player)

            // Check if cancelled again after waiting
            guard !Task.isCancelled else {
                await MainActor.run {
                    self.isLoading = false
                    onLoadingStateChanged?(false, nil)
                }
                return
            }

            await MainActor.run {
                self.isLoading = false
                onLoadingStateChanged?(false, nil)
                self.presentPlayerViewController(with: player)
            }
        }
    }

    /// Cancels the current loading operation.
    func cancelLoading() {
        loadingTask?.cancel()
        loadingTask = nil
        isLoading = false
        viewModel?.cleanup()
        viewModel = nil
        Log.info(.playback, "Loading cancelled by user")
    }

    /// Dismisses the video player.
    /// - Parameter animated: Whether to animate the dismissal.
    func dismiss(animated: Bool = true) {
        guard let playerVC = playerViewController else { return }

        // Don't dismiss if in PiP mode
        guard !isInPictureInPicture else { return }

        playerVC.dismiss(animated: animated) { [weak self] in
            self?.cleanup()
            self?.onDismiss?()
        }
    }

    /// Cleans up resources when playback ends.
    func cleanup() {
        viewModel?.cleanup()
        viewModel = nil
        playerViewController = nil
        isInPictureInPicture = false
        onDismiss = nil
        onEpisodeFinished = nil
    }


    //#################################################################################
    // MARK: - Private Methods
    //#################################################################################

    private func waitForPlayerReady(_ player: AVPlayer) async {
        // If already ready, return immediately
        if player.status == .readyToPlay {
            return
        }

        // Wait for the player status to change to readyToPlay
        await withCheckedContinuation { continuation in
            var observation: NSKeyValueObservation?
            observation = player.observe(\.status, options: [.new]) { player, _ in
                if player.status == .readyToPlay || player.status == .failed {
                    observation?.invalidate()
                    continuation.resume()
                }
            }

            // Handle case where status changes before observation is set up
            if player.status == .readyToPlay || player.status == .failed {
                observation?.invalidate()
                continuation.resume()
            }
        }
    }

    private func presentPlayerViewController(with player: AVPlayer) {
        let playerVC = AVPlayerViewController()
        playerVC.player = player
        playerVC.delegate = self
        playerVC.allowsPictureInPicturePlayback = true
        playerVC.canStartPictureInPictureAutomaticallyFromInline = true
        playerVC.updatesNowPlayingInfoCenter = false

        self.playerViewController = playerVC

        // Find the root view controller to present from
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else {
            Log.error(.playback, "Could not find root view controller")
            return
        }

        // Find the topmost presented controller
        var topController = rootVC
        while let presented = topController.presentedViewController {
            topController = presented
        }

        playerVC.modalPresentationStyle = .fullScreen
        topController.present(playerVC, animated: true)
    }
}


//#################################################################################
// MARK: - AVPlayerViewControllerDelegate
//#################################################################################

extension VideoPlayerPresenter: AVPlayerViewControllerDelegate {

    nonisolated func playerViewControllerWillStartPictureInPicture(_ playerViewController: AVPlayerViewController) {
        Task { @MainActor in
            isInPictureInPicture = true
        }
    }

    nonisolated func playerViewControllerDidStopPictureInPicture(_ playerViewController: AVPlayerViewController) {
        Task { @MainActor in
            isInPictureInPicture = false

            // If there's no presented player controller, clean up
            if self.playerViewController?.presentingViewController == nil {
                cleanup()
                onDismiss?()
            }
        }
    }

    nonisolated func playerViewController(_ playerViewController: AVPlayerViewController,
                                          restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
        Task { @MainActor in
            if let playerVC = self.playerViewController,
               playerVC.presentingViewController != nil {
                completionHandler(true)
            } else if let player = self.viewModel?.player {
                presentPlayerViewController(with: player)
                completionHandler(true)
            } else {
                completionHandler(false)
            }
        }
    }

    nonisolated func playerViewControllerShouldAutomaticallyDismissAtPictureInPictureStart(_ playerViewController: AVPlayerViewController) -> Bool {
        true
    }

    nonisolated func playerViewController(_ playerViewController: AVPlayerViewController,
                                          willEndFullScreenPresentationWithAnimationCoordinator coordinator: any UIViewControllerTransitionCoordinator) {
        Task { @MainActor [weak self] in
            coordinator.animate(alongsideTransition: nil) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self else { return }

                    // Only cleanup if not in PiP mode
                    if !self.isInPictureInPicture {
                        self.cleanup()
                        self.onDismiss?()
                    }
                }
            }
        }
    }
}
#endif
