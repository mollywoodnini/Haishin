//
//  EpisodeListView.swift
//  Miru
//
//  Created by Miru on 24.01.26.
//

import Kingfisher
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
    // MARK: - Loading View
    //#################################################################################

    private var loadingView: some View {
        VStack(spacing: .spacingM) {
            ProgressView()
            Text("Loading episodes...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }


    //#################################################################################
    // MARK: - Error View
    //#################################################################################

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


    //#################################################################################
    // MARK: - Episodes List View
    //#################################################################################

    private func episodesListView(anime: Anime) -> some View {
        let hasMultipleRanges = anime.episodeRanges.count > 1

        return ScrollView {
            LazyVStack(alignment: .leading, spacing: .spacingM) {
                animeHeaderView(anime: anime)

                if let continueEpisode = viewModel.getContinueWatchingEpisode(from: anime.episodes) {
                    continueWatchingButton(episode: continueEpisode)
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


    //#################################################################################
    // MARK: - Continue Watching Button
    //#################################################################################

    private func continueWatchingButton(episode: Episode) -> some View {
        Button {
            selectedEpisode = episode
        } label: {
            HStack(spacing: .spacingM) {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.accentColor)

                VStack(alignment: .leading, spacing: .spacingXXS) {
                    Text("Continue Watching")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("Episode \(episode.number)")
                        .font(.headline)
                        .foregroundStyle(.primary)
                }

                Spacer()
            }
            .padding(.spacingM)
            .background(Color(.tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusS))
        }
        .buttonStyle(.plain)
    }


    //#################################################################################
    // MARK: - Flat Episodes List View
    //#################################################################################

    private func flatEpisodesListView(episodes: [Episode]) -> some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(episodes) { episode in
                episodeRowView(episode: episode)

                if episode.id != episodes.last?.id {
                    Divider()
                        .padding(.leading, .spacingS)
                }
            }
        }
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusS))
    }


    //#################################################################################
    // MARK: - Anime Header View
    //#################################################################################

    private func animeHeaderView(anime: Anime) -> some View {
        HStack(alignment: .top, spacing: .spacingM) {
            KFImage(anime.coverURL)
                .resizable()
                .placeholder {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 80, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusS))

            VStack(alignment: .leading, spacing: .spacingXS) {
                Text(anime.title)
                    .font(.headline)
                    .lineLimit(2)

                if !anime.genres.isEmpty {
                    Text(anime.genres.joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Text("\(anime.episodes.count) Episode\(anime.episodes.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }


    //#################################################################################
    // MARK: - Episode Ranges View
    //#################################################################################

    private func episodeRangesView(ranges: [EpisodeRange]) -> some View {
        LazyVStack(alignment: .leading, spacing: .spacingS) {
            ForEach(ranges) { range in
                episodeRangeSectionView(range: range)
            }
        }
    }


    //#################################################################################
    // MARK: - Episode Range Section View
    //#################################################################################

    private func episodeRangeSectionView(range: EpisodeRange) -> some View {
        let isExpanded = expandedRanges.contains(range.id)

        return VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if isExpanded {
                        expandedRanges.remove(range.id)
                    } else {
                        expandedRanges.insert(range.id)
                    }
                }
            } label: {
                HStack {
                    Text(range.title)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Spacer()

                    Text("\(range.episodes.count) ep")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.vertical, .spacingXS)
                .padding(.horizontal, .spacingS)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusS))
            }
            .buttonStyle(.plain)

            if isExpanded {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(range.episodes) { episode in
                        episodeRowView(episode: episode)

                        if episode.id != range.episodes.last?.id {
                            Divider()
                                .padding(.leading, .spacingS)
                        }
                    }
                }
                .background(Color(.tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusS))
                .padding(.top, .spacingXS)
            }
        }
    }


    //#################################################################################
    // MARK: - Episode Row View
    //#################################################################################

    private func episodeTitle(for episode: Episode) -> String {
        guard let title = episode.title, title != "\(episode.number)" else {
            return "Episode \(episode.number)"
        }
        return title
    }

    private func episodeRowView(episode: Episode) -> some View {
        let progress = viewModel.watchProgressMap[episode.id]
        let downloadState = viewModel.getDownloadState(for: episode.id)

        return VStack(alignment: .leading, spacing: .spacingXS) {
            HStack(spacing: .spacingS) {
                Text("\(episode.number)")
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

                    if let downloadState, case .downloading(let downloadProgress) = downloadState {
                        Text("Downloading (\(Int(downloadProgress * 100)) % complete)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if let progress, !progress.isCompleted {
                        Text("\(Int((1 - progress.progress) * 100)) % left")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if downloadState == nil {
                        Text("Start Now")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Download button
                downloadButton(for: episode, downloadState: downloadState)

                if let progress, progress.isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.body)
                        .foregroundStyle(.green)
                }
            }

            if let downloadState, case .downloading(let downloadProgress) = downloadState {
                ProgressBarView(progress: downloadProgress)
            } else if let progress, !progress.isCompleted, progress.progress > 0 {
                ProgressBarView(progress: progress.progress)
            }
        }
        .padding(.horizontal, .spacingS)
        .padding(.vertical, .spacingXS)
        .contentShape(Rectangle())
        .onTapGesture {
            selectedEpisode = episode
        }
    }

    @ViewBuilder
    private func downloadButton(for episode: Episode, downloadState: DownloadState?) -> some View {
        switch downloadState {
        case .downloading(let progress):
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                    .frame(width: 24, height: 24)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .frame(width: 24, height: 24)
                    .rotationEffect(.degrees(-90))

                Image(systemName: "stop.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(Color.accentColor)
            }
            .onTapGesture {
                viewModel.cancelDownload(episodeId: episode.id)
            }

        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(.green)

        case .pending:
            ProgressView()
                .frame(width: 24, height: 24)

        case .failed, .cancelled, nil:
            Button {
                viewModel.startDownload(episode: episode)
            } label: {
                Image(systemName: "icloud.and.arrow.down")
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)
        }
    }
}


//#################################################################################
// MARK: - ProgressBarView
//#################################################################################

/// A simple progress bar view for displaying watch progress.
private struct ProgressBarView: View {

    //#################################################################################
    // MARK: - Constants
    //#################################################################################

    private struct Constants {
        static let barHeight: CGFloat = 4
    }


    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    let progress: Double


    //#################################################################################
    // MARK: - Body
    //#################################################################################

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: Constants.barHeight / 2)
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: Constants.barHeight)

                RoundedRectangle(cornerRadius: Constants.barHeight / 2)
                    .fill(Color.accentColor)
                    .frame(width: geometry.size.width * progress, height: Constants.barHeight)
            }
        }
        .frame(height: Constants.barHeight)
    }
}
