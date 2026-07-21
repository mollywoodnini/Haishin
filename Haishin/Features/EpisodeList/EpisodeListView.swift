//
//  EpisodeListView.swift
//  Haishin
//
//  Created by Tan Nghia La on 24.01.26.
//

import SwiftUI
import UIKit


//#################################################################################
// MARK: - EpisodeListView
//#################################################################################

/// View for displaying episodes from a JavaScript source or downloaded episodes.
struct EpisodeListView: View {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    @State private var viewModel: EpisodeListViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var expandedRanges: Set<String> = []
    @State private var isLoadingVideo = false
    @State private var videoLoadError: Error?
    @State private var showingVideoError = false
    @State private var showShareSheet = false

    private var logText: String {
        JSRuntimeLogCollector.shared.messages.joined(separator: "\n")
    }


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new episodes view with an existing view model.
    /// - Parameter viewModel: The view model to use.
    init(viewModel: EpisodeListViewModel) {
        self._viewModel = State(initialValue: viewModel)
    }


    //#################################################################################
    // MARK: - Body
    //#################################################################################

    var body: some View {
        Group {
            if viewModel.mode.isOnline {
                onlineModeContent
            } else {
                offlineModeContent
            }
        }
        .navigationTitle(viewModel.mode.isOffline ? "Downloads" : "Episodes")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if viewModel.mode.isOnline {
                ToolbarItem(placement: .primaryAction) {
                    onlineToolbarMenu
                }
            }
        }
        .task {
            await viewModel.loadEpisodes()
        }
        .onChange(of: viewModel.hasDownloadedEpisodes) { _, hasEpisodes in
            // Dismiss if all episodes have been deleted in offline mode
            if viewModel.mode.isOffline && !hasEpisodes {
                dismiss()
            }
        }
        .overlay {
            if isLoadingVideo {
                VideoLoadingOverlayView(
                    messages: JSRuntimeLogCollector.shared.messages,
                    onCancel: cancelVideoLoading
                )
            }
        }
        .alert("Failed to Load Video", isPresented: $showingVideoError) {
            Button("OK", role: .cancel) {
                videoLoadError = nil
            }
            Button("Share Logs") {
                showShareSheet = true
            }
        } message: {
            Text(videoLoadError?.localizedDescription ?? "An unknown error occurred while loading the video.")
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(text: logText)
        }
    }


    //#################################################################################
    // MARK: - Private Methods
    //#################################################################################

    private func playEpisode(_ episode: Episode) {
        JSRuntimeLogCollector.shared.clear()
        let playerViewModel = viewModel.makeVideoPlayerViewModel(episode: episode)

        VideoPlayerPresenter.shared.present(
            viewModel: playerViewModel,
            onDismiss: { [viewModel] in
                viewModel.loadWatchProgress()
            },
            onEpisodeFinished: { [viewModel] finishedEpisode in
                // Check if there's a next episode to play
                if let nextEpisode = viewModel.getNextEpisode(after: finishedEpisode) {
                    // Dismiss current and play next
                    VideoPlayerPresenter.shared.dismiss(animated: false)
                    Task { @MainActor in
                        // Small delay to allow dismissal to complete
                        try? await Task.sleep(for: .milliseconds(100))
                        playEpisode(nextEpisode)
                    }
                }
            },
            onLoadingStateChanged: { isLoading, error in
                isLoadingVideo = isLoading
                if let error {
                    videoLoadError = error
                    showingVideoError = true
                }
            }
        )
    }

    private func cancelVideoLoading() {
        VideoPlayerPresenter.shared.cancelLoading()
        isLoadingVideo = false
    }


    //#################################################################################
    // MARK: - Online Mode Views
    //#################################################################################

    @ViewBuilder
    private var onlineModeContent: some View {
        ZStack {
            if viewModel.isLoading && viewModel.sourceVideo == nil {
                loadingView
            } else if let error = viewModel.error {
                errorView(error: error)
            } else if let video = viewModel.sourceVideo {
                onlineEpisodesListView(video: video)
            } else {
                Color.clear
            }
        }
    }

    private var onlineToolbarMenu: some View {
        Menu {
            Button {
                viewModel.toggleSubscription()
            } label: {
                Label(
                    viewModel.isSubscribed ? "Unsubscribe" : "Subscribe",
                    systemImage: viewModel.isSubscribed ? "bell.slash" : "bell"
                )
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }

    private var loadingView: some View {
        VStack(spacing: .spacingM) {
            ProgressView()
            Text("Loading episodes...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(error: Error) -> some View {
        let isSourceNotFound = (error as? EpisodesError) == .sourceNotFoundHint

        return VStack(spacing: .spacingM) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("Failed to Load Episodes")
                .font(.headline)

            Text(error.localizedDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, .spacingL)

            if isSourceNotFound {
                Button("Go Back") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button("Retry") {
                    Task {
                        await viewModel.retry()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func onlineEpisodesListView(video: Video) -> some View {
        let hasMultipleRanges = video.episodeRanges.count > 1

        return ScrollView {
            LazyVStack(alignment: .leading, spacing: .spacingM) {
                // Prefer AniList/preview cover URL, fallback to source cover if needed
                EpisodeListHeaderView(
                    title: video.title,
                    sourceName: viewModel.sourceName,
                    coverURL: viewModel.videoCoverURL ?? video.coverURL,
                    subtitle: video.genres.isEmpty ? nil : video.genres.joined(separator: ", "),
                    episodeCount: video.episodes.count
                )

                if let continueEpisode = viewModel.getContinueWatchingEpisode(from: video.episodes) {
                    ContinueWatchingButtonView(episode: continueEpisode) {
                        playEpisode(continueEpisode)
                    }
                }

                if hasMultipleRanges {
                    onlineEpisodeRangesView(ranges: video.episodeRanges)
                } else {
                    onlineFlatEpisodesListView(episodes: video.episodes)
                }
            }
            .padding(.spacingS)
        }
        .onAppear {
            if let firstRange = video.episodeRanges.first {
                expandedRanges.insert(firstRange.id)
            }
        }
    }

    private func onlineFlatEpisodesListView(episodes: [Episode]) -> some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(episodes) { episode in
                EpisodeRowView(
                    episode: episode,
                    progress: viewModel.watchProgressMap[episode.id],
                    downloadState: viewModel.getDownloadState(for: episode.id),
                    onTap: { playEpisode(episode) },
                    onDownload: { viewModel.startDownload(episode: episode) },
                    onCancelDownload: { viewModel.cancelDownload(episodeId: episode.id) }
                )

                if episode.id != episodes.last?.id {
                    Divider()
                        .padding(.leading, .spacingS)
                }
            }
        }
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusS))
    }

    private func onlineEpisodeRangesView(ranges: [EpisodeRange]) -> some View {
        LazyVStack(alignment: .leading, spacing: .spacingS) {
            ForEach(ranges) { range in
                EpisodeRangeSectionView(
                    range: range,
                    isExpanded: expandedRanges.contains(range.id),
                    watchProgressMap: viewModel.watchProgressMap,
                    onToggle: {
                        if expandedRanges.contains(range.id) {
                            expandedRanges.remove(range.id)
                        } else {
                            expandedRanges.insert(range.id)
                        }
                    },
                    getDownloadState: { viewModel.getDownloadState(for: $0) },
                    onEpisodeTap: { playEpisode($0) },
                    onDownload: { viewModel.startDownload(episode: $0) },
                    onCancelDownload: { viewModel.cancelDownload(episodeId: $0) }
                )
            }
        }
    }


    //#################################################################################
    // MARK: - Offline Mode Views
    //#################################################################################

    @ViewBuilder
    private var offlineModeContent: some View {
        if viewModel.offlineEpisodes.isEmpty {
            ContentUnavailableView {
                Label("No Downloaded Episodes", systemImage: "arrow.down.circle")
            } description: {
                Text("Downloaded episodes will appear here.")
            }
        } else {
            offlineEpisodesListView
        }
    }

    private var offlineEpisodesListView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: .spacingM) {
                EpisodeListHeaderView(
                    title: viewModel.videoTitle,
                    sourceName: viewModel.sourceName,
                    coverURL: viewModel.videoCoverURL,
                    subtitle: nil,
                    episodeCount: viewModel.offlineEpisodes.count
                )

                if let continueEpisode = viewModel.getContinueWatchingEpisode(from: viewModel.offlineEpisodes) {
                    ContinueWatchingButtonView(episode: continueEpisode) {
                        playEpisode(continueEpisode)
                    }
                }

                offlineFlatEpisodesListView
            }
            .padding(.spacingS)
        }
    }

    private var offlineFlatEpisodesListView: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(viewModel.offlineEpisodes) { episode in
                EpisodeRowView(
                    episode: episode,
                    progress: viewModel.watchProgressMap[episode.id],
                    onTap: { playEpisode(episode) },
                    onDelete: { viewModel.deleteDownload(episodeId: episode.id) }
                )

                if episode.id != viewModel.offlineEpisodes.last?.id {
                    Divider()
                        .padding(.leading, .spacingS)
                }
            }
        }
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusS))
    }
}


//#################################################################################
// MARK: - VideoLoadingOverlayView
//#################################################################################

private struct VideoLoadingOverlayView: View {

    private let messages: [String]
    private let onCancel: () -> Void

    init(messages: [String], onCancel: @escaping () -> Void) {
        self.messages = messages
        self.onCancel = onCancel
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()

            VStack(spacing: .spacingS) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
                    .padding(.top, .spacingS)

                Text("Loading video...")
                    .font(.headline)
                    .foregroundStyle(.white)

                if !messages.isEmpty {
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(alignment: .leading, spacing: 2) {
                                ForEach(Array(messages.enumerated()), id: \.offset) { index, message in
                                    Text(message)
                                        .font(.caption2)
                                        .foregroundStyle(.white.opacity(0.8))
                                        .fontDesign(.monospaced)
                                        .id(index)
                                }
                            }
                        }
                        .frame(maxHeight: 180)
                        .padding(.horizontal, .spacingS)
                        .onChange(of: messages.count) { _, _ in
                            withAnimation {
                                proxy.scrollTo(messages.count - 1, anchor: .bottom)
                            }
                        }
                    }
                }

                Button {
                    onCancel()
                } label: {
                    Text("Cancel")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, .spacingL)
                        .padding(.vertical, .spacingS)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Capsule())
                }
                .padding(.top, .spacingS)
            }
            .padding(.spacingS)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusM))
        }
    }
}


//#################################################################################
// MARK: - ShareSheet
//#################################################################################

/// A UIViewControllerRepresentable for presenting UIActivityViewController.
private struct ShareSheet: UIViewControllerRepresentable {

    let text: String

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [text], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
