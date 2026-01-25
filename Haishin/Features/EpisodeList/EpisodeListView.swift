//
//  EpisodeListView.swift
//  Miru
//
//  Created by Miru on 24.01.26.
//

import SwiftUI


//#################################################################################
// MARK: - EpisodeListView
//#################################################################################

/// View for displaying episodes from a JavaScript source.
struct EpisodeListView: View {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    @State private var viewModel: EpisodeListViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingSourcePicker = false
    @State private var expandedRanges: Set<String> = []
    @State private var selectedEpisode: Episode?


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new episodes view with an existing view model.
    /// - Parameter viewModel: The view model to use.
    init(viewModel: EpisodeListViewModel) {
        self._viewModel = State(initialValue: viewModel)
    }

    /// Creates a new episodes view.
    /// - Parameters:
    ///   - aniListAnime: The AniList anime details.
    ///   - sourceId: The selected source ID.
    ///   - sourceManager: The shared source manager.
    ///   - watchProgressService: The service for accessing watch progress.
    ///   - subscriptionService: The service for managing subscriptions.
    ///   - userPreferences: The user preferences.
    init(aniListAnime: AniListAnimeDetail,
         sourceId: String,
         sourceManager: SourceManaging,
         watchProgressService: WatchProgressServiceProtocol,
         subscriptionService: SubscriptionServiceProtocol,
         userPreferences: UserPreferences = UserPreferences()) {
        self._viewModel = State(initialValue: EpisodeListViewModel(aniListAnime: aniListAnime,
                                                                   sourceId: sourceId,
                                                                   sourceManager: sourceManager,
                                                                   watchProgressService: watchProgressService,
                                                                   subscriptionService: subscriptionService,
                                                                   userPreferences: userPreferences))
    }


    //#################################################################################
    // MARK: - Body
    //#################################################################################

    var body: some View {
        ZStack {
            if viewModel.isLoading && viewModel.sourceAnime == nil {
                loadingView
            } else if let error = viewModel.error {
                errorView(error: error)
            } else if let anime = viewModel.sourceAnime {
                episodesListView(anime: anime)
            } else {
                Color.clear
            }
        }
        .navigationTitle("Episodes")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                toolbarMenu
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
        .fullScreenCover(item: $selectedEpisode, onDismiss: {
            viewModel.loadWatchProgress()
        }) { episode in
            VideoPlayerView(viewModel: viewModel.makeVideoPlayerViewModel(episode: episode))
        }
    }


    //#################################################################################
    // MARK: - Private Views
    //#################################################################################

    private var toolbarMenu: some View {
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

    private func episodesListView(anime: Anime) -> some View {
        let hasMultipleRanges = anime.episodeRanges.count > 1

        return ScrollView {
            LazyVStack(alignment: .leading, spacing: .spacingM) {
                EpisodeListHeaderView(anime: anime)

                if let continueEpisode = viewModel.getContinueWatchingEpisode(from: anime.episodes) {
                    ContinueWatchingButtonView(episode: continueEpisode) {
                        selectedEpisode = continueEpisode
                    }
                }

                if hasMultipleRanges {
                    episodeRangesView(ranges: anime.episodeRanges)
                } else {
                    flatEpisodesListView(episodes: anime.episodes)
                }
            }
            .padding(.spacingM)
        }
        .onAppear {
            if let firstRange = anime.episodeRanges.first {
                expandedRanges.insert(firstRange.id)
            }
        }
    }

    private func flatEpisodesListView(episodes: [Episode]) -> some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(episodes) { episode in
                EpisodeRowView(episode: episode,
                               progress: viewModel.watchProgressMap[episode.id],
                               downloadState: viewModel.getDownloadState(for: episode.id),
                               onTap: { selectedEpisode = episode },
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

    private func episodeRangesView(ranges: [EpisodeRange]) -> some View {
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
                                        onEpisodeTap: { selectedEpisode = $0 },
                                        onDownload: { viewModel.startDownload(episode: $0) },
                                        onCancelDownload: { viewModel.cancelDownload(episodeId: $0) })
            }
        }
    }
}
