//
//  EpisodeListView.swift
//  Haishin
//
//  Created by Haishin on 24.01.26.
//

import SwiftUI


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
    @State private var showingSourcePicker = false
    @State private var expandedRanges: Set<String> = []
    @State private var isLoadingVideo = false
    @State private var videoLoadError: Error?
    @State private var showingVideoError = false


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new episodes view with an existing view model.
    /// - Parameter viewModel: The view model to use.
    init(viewModel: EpisodeListViewModel) {
        self._viewModel = State(initialValue: viewModel)
    }

    /// Creates a new episodes view for offline mode (downloaded episodes).
    /// - Parameter downloadedAnime: The downloaded anime to display.
    /// - Parameter watchProgressService: The service for accessing watch progress.
    /// - Parameter downloadService: The download service.
    init(downloadedAnime: DownloadedAnime,
         watchProgressService: WatchProgressServiceProtocol,
         downloadService: DownloadServiceProtocol) {
        self._viewModel = State(initialValue: EpisodeListViewModel(downloadedAnime: downloadedAnime,
                                                                   watchProgressService: watchProgressService,
                                                                   downloadService: downloadService))
    }


    //#################################################################################
    // MARK: - Body
    //#################################################################################

    var body: some View {
        Group {
            switch viewModel.mode {
            case .online:
                onlineModeContent
            case .offline:
                offlineModeContent
            }
        }
        .navigationTitle(viewModel.mode == .offline ? "Downloads" : "Episodes")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if viewModel.mode == .online {
                ToolbarItem(placement: .primaryAction) {
                    onlineToolbarMenu
                }
            }
        }
        .sheet(isPresented: $showingSourcePicker) {
            SourcePickerView(animeTitle: viewModel.animeTitle,
                             selectedSourceId: Binding(
                                get: { viewModel.selectedSourceId },
                                set: { viewModel.selectedSourceId = $0 }
                             ),
                             onSourceSelected: {
                                 showingSourcePicker = false
                                 dismiss()
                             },
                             sources: viewModel.installedSources)
        }
        .task {
            await viewModel.loadEpisodes()
        }
        .onChange(of: viewModel.hasDownloadedEpisodes) { _, hasEpisodes in
            // Dismiss if all episodes have been deleted in offline mode
            if viewModel.mode == .offline && !hasEpisodes {
                dismiss()
            }
        }
        .overlay {
            if isLoadingVideo {
                videoLoadingOverlay
            }
        }
        .alert("Failed to Load Video", isPresented: $showingVideoError) {
            Button("OK", role: .cancel) {
                videoLoadError = nil
            }
        } message: {
            Text(videoLoadError?.localizedDescription ?? "An unknown error occurred while loading the video.")
        }
    }


    //#################################################################################
    // MARK: - Private Methods
    //#################################################################################

    private func playEpisode(_ episode: Episode) {
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
            if viewModel.isLoading && viewModel.sourceAnime == nil {
                loadingView
            } else if let error = viewModel.error {
                errorView(error: error)
            } else if let anime = viewModel.sourceAnime {
                onlineEpisodesListView(anime: anime)
            } else {
                Color.clear
            }
        }
    }

    private var onlineToolbarMenu: some View {
        Menu {
            Button {
                showingSourcePicker = true
            } label: {
                Label("Change Source", systemImage: "arrow.triangle.2.circlepath")
            }

            Divider()

            Button {
                viewModel.toggleSubscription()
            } label: {
                Label(viewModel.isSubscribed ? "Unsubscribe" : "Subscribe",
                      systemImage: viewModel.isSubscribed ? "bell.slash" : "bell")
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

    private var videoLoadingOverlay: some View {
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

                Button {
                    cancelVideoLoading()
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
                Button("Select Different Source") {
                    viewModel.clearSelectedSource()
                    showingSourcePicker = true
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

    private func onlineEpisodesListView(anime: Anime) -> some View {
        let hasMultipleRanges = anime.episodeRanges.count > 1

        return ScrollView {
            LazyVStack(alignment: .leading, spacing: .spacingM) {
                // Prefer AniList/preview cover URL, fallback to source cover if needed
                EpisodeListHeaderView(title: anime.title,
                                      coverURL: viewModel.animeCoverURL ?? anime.coverURL,
                                      subtitle: anime.genres.isEmpty ? nil : anime.genres.joined(separator: ", "),
                                      episodeCount: anime.episodes.count)

                if let continueEpisode = viewModel.getContinueWatchingEpisode(from: anime.episodes) {
                    ContinueWatchingButtonView(episode: continueEpisode) {
                        playEpisode(continueEpisode)
                    }
                }

                if hasMultipleRanges {
                    onlineEpisodeRangesView(ranges: anime.episodeRanges)
                } else {
                    onlineFlatEpisodesListView(episodes: anime.episodes)
                }
            }
            .padding(.spacingS)
        }
        .onAppear {
            if let firstRange = anime.episodeRanges.first {
                expandedRanges.insert(firstRange.id)
            }
        }
    }

    private func onlineFlatEpisodesListView(episodes: [Episode]) -> some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(episodes) { episode in
                EpisodeRowView(episode: episode,
                               progress: viewModel.watchProgressMap[episode.id],
                               downloadState: viewModel.getDownloadState(for: episode.id),
                               onTap: { playEpisode(episode) },
                               onDownload: { viewModel.startDownload(episode: episode) },
                               onCancelDownload: { viewModel.cancelDownload(episodeId: episode.id) })

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
                EpisodeRangeSectionView(range: range,
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
                                        onCancelDownload: { viewModel.cancelDownload(episodeId: $0) })
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
                EpisodeListHeaderView(title: viewModel.animeTitle,
                                      coverURL: viewModel.animeCoverURL,
                                      subtitle: viewModel.sourceName,
                                      episodeCount: viewModel.offlineEpisodes.count)

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
                EpisodeRowView(episode: episode,
                               progress: viewModel.watchProgressMap[episode.id],
                               onTap: { playEpisode(episode) },
                               onDelete: { viewModel.deleteDownload(episodeId: episode.id) })

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
