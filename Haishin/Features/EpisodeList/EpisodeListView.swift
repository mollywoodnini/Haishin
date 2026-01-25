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

/// View for displaying episodes from a JavaScript source or downloaded episodes.
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

    /// Creates a new episodes view for online mode.
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

    /// Creates a new episodes view for offline mode (downloaded episodes).
    /// - Parameter downloadedAnime: The downloaded anime to display.
    init(downloadedAnime: DownloadedAnime) {
        self._viewModel = State(initialValue: EpisodeListViewModel(downloadedAnime: downloadedAnime))
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
        .fullScreenCover(item: $selectedEpisode, onDismiss: {
            viewModel.loadWatchProgress()
        }) { episode in
            VideoPlayerView(viewModel: viewModel.makeVideoPlayerViewModel(episode: episode))
        }
        .onChange(of: viewModel.hasDownloadedEpisodes) { _, hasEpisodes in
            // Dismiss if all episodes have been deleted in offline mode
            if viewModel.mode == .offline && !hasEpisodes {
                dismiss()
            }
        }
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
                EpisodeListHeaderView(anime: anime)

                if let continueEpisode = viewModel.getContinueWatchingEpisode(from: anime.episodes) {
                    ContinueWatchingButtonView(episode: continueEpisode) {
                        selectedEpisode = continueEpisode
                    }
                }

                if hasMultipleRanges {
                    onlineEpisodeRangesView(ranges: anime.episodeRanges)
                } else {
                    onlineFlatEpisodesListView(episodes: anime.episodes)
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

    private func onlineFlatEpisodesListView(episodes: [Episode]) -> some View {
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
                                        onEpisodeTap: { selectedEpisode = $0 },
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
        List {
            // Header section
            Section {
                offlineHeaderView
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)

            // Continue watching
            if let continueEpisode = viewModel.getContinueWatchingEpisode(from: viewModel.offlineEpisodes) {
                Section {
                    ContinueWatchingButtonView(episode: continueEpisode) {
                        selectedEpisode = continueEpisode
                    }
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            // Episodes section
            Section {
                ForEach(viewModel.offlineEpisodes) { episode in
                    offlineEpisodeRow(episode: episode)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedEpisode = episode
                        }
                }
                .onDelete(perform: deleteEpisodes)
            } header: {
                Text("Episodes")
            }
        }
        .listStyle(.insetGrouped)
    }

    private var offlineHeaderView: some View {
        HStack(alignment: .top, spacing: .spacingM) {
            AsyncImage(url: viewModel.animeCoverURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
            }
            .frame(width: 80, height: 120)
            .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusS))

            VStack(alignment: .leading, spacing: .spacingXS) {
                Text(viewModel.animeTitle)
                    .font(.headline)
                    .lineLimit(2)

                if let sourceName = viewModel.sourceName {
                    Text(sourceName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text("\(viewModel.offlineEpisodes.count) Episode\(viewModel.offlineEpisodes.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.spacingM)
    }

    private func offlineEpisodeRow(episode: Episode) -> some View {
        HStack(spacing: .spacingS) {
            Text(episode.number)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 32)
                .background(Color.accentColor)
                .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusXS))

            VStack(alignment: .leading, spacing: .spacingXXS) {
                Text(episodeTitle(for: episode))
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if let progress = viewModel.watchProgressMap[episode.id] {
                    if progress.isCompleted {
                        Text("Completed")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("\(Int((1 - progress.progress) * 100))% left")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("Not watched")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if let progress = viewModel.watchProgressMap[episode.id], progress.isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.body)
                    .foregroundStyle(.green)
            }
        }
    }

    private func episodeTitle(for episode: Episode) -> String {
        guard let title = episode.title, title != episode.number else {
            return "Episode \(episode.number)"
        }
        return title
    }

    private func deleteEpisodes(at offsets: IndexSet) {
        for index in offsets {
            let episode = viewModel.offlineEpisodes[index]
            viewModel.deleteDownload(episodeId: episode.id)
        }
    }
}
