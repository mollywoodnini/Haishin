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
    @State private var userPreferences = UserPreferences()
    @State private var expandedRanges: Set<String> = []
    @State private var selectedEpisode: Episode?
    @State private var isSubscribed = false
    @State private var watchProgressMap: [String: WatchProgress] = [:]

    private let sourceManager: SourceManager
    private let watchProgressService: WatchProgressServiceProtocol


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new episodes view.
    /// - Parameters:
    ///   - aniListAnime: The AniList anime details.
    ///   - sourceId: The selected source ID.
    ///   - sourceManager: The shared source manager.
    ///   - watchProgressService: The service for accessing watch progress.
    init(aniListAnime: AniListAnimeDetail,
         sourceId: String,
         sourceManager: SourceManager,
         watchProgressService: WatchProgressServiceProtocol) {
        print("[EpisodeListView] init called for anime: '\(aniListAnime.title)', sourceId: '\(sourceId)'")
        self.sourceManager = sourceManager
        self.watchProgressService = watchProgressService
        self._viewModel = State(initialValue: EpisodeListViewModel(aniListAnime: aniListAnime,
                                                                sourceId: sourceId,
                                                                sourceManager: sourceManager))
        print("[EpisodeListView] init complete. ViewModel isLoading: \(self._viewModel.wrappedValue.isLoading)")
    }


    //#################################################################################
    // MARK: - Body
    //#################################################################################

    var body: some View {
        let _ = print("[EpisodeListView] body evaluated. isLoading: \(viewModel.isLoading), sourceAnime: \(viewModel.sourceAnime != nil ? "exists" : "nil"), error: \(viewModel.error != nil ? "exists" : "nil")")
        
        ZStack {
            if viewModel.isLoading && viewModel.sourceAnime == nil {
                loadingView
            } else if let error = viewModel.error {
                errorView(error: error)
            } else if let anime = viewModel.sourceAnime {
                episodesListView(anime: anime)
            } else {
                // Empty state - should never reach here but ensures view is rendered
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
                        isSubscribed.toggle()
                    } label: {
                        Label(isSubscribed ? "Unsubscribe" : "Subscribe",
                              systemImage: isSubscribed ? "bell.slash" : "bell")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingSourcePicker) {
            SourcePickerView(animeTitle: viewModel.aniListAnime.title,
                             selectedSourceId: $userPreferences.selectedSourceId,
                             onSourceSelected: {
                                 showingSourcePicker = false
                                 // Dismiss and let the anime detail view handle navigation
                                 dismiss()
                             },
                             sourceManager: sourceManager)
        }
        .task {
            print("[EpisodeListView] .task modifier fired")
            await viewModel.loadEpisodes()
            loadWatchProgress()
        }
        .fullScreenCover(item: $selectedEpisode) { episode in
            VideoPlayerView(episode: episode,
                            animeId: viewModel.aniListAnime.id,
                            animeTitle: viewModel.aniListAnime.title,
                            sourceId: viewModel.sourceId,
                            sourceManager: sourceManager)
        }
        .onChange(of: selectedEpisode) { _, newValue in
            // Reload progress when video player is dismissed
            if newValue == nil {
                loadWatchProgress()
            }
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
        let _ = print("[EpisodeListView] Showing error: \(error)")
        let _ = print("[EpisodeListView] Error type: \(type(of: error))")
        let isSourceNotFound = (error as? EpisodesError) == .sourceNotFoundHint
        let _ = print("[EpisodeListView] Is source not found error: \(isSourceNotFound)")
        
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
            
            // Special handling for source not found error
            if let episodesError = error as? EpisodesError, episodesError == .sourceNotFoundHint {
                Button("Select Different Source") {
                    print("[EpisodeListView] 'Select Different Source' button tapped")
                    // Clear the invalid source selection
                    userPreferences.selectedSourceId = nil
                    print("[EpisodeListView] Cleared selectedSourceId, showing picker")
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
                // Header with anime info
                animeHeaderView(anime: anime)

                // Continue Watching button (if applicable)
                if let continueEpisode = getContinueWatchingEpisode(from: anime.episodes) {
                    continueWatchingButton(episode: continueEpisode)
                }

                // Show flat list for single range, collapsible sections for multiple ranges
                if hasMultipleRanges {
                    episodeRangesView(ranges: anime.episodeRanges)
                } else {
                    // Flat episode list without section header
                    flatEpisodesListView(episodes: anime.episodes)
                }
            }
            .padding(.spacingM)
        }
        .onAppear {
            // Expand first range by default (only relevant for multiple ranges)
            if let firstRange = anime.episodeRanges.first {
                expandedRanges.insert(firstRange.id)
            }
        }
    }


    //#################################################################################
    // MARK: - Continue Watching Button
    //#################################################################################

    private func getContinueWatchingEpisode(from episodes: [Episode]) -> Episode? {
        // Sort episodes by number to find the latest watched
        let sortedEpisodes = episodes.sorted { ep1, ep2 in
            (Int(ep1.number) ?? 0) < (Int(ep2.number) ?? 0)
        }

        // Find the last episode that has progress
        var lastWatchedIndex: Int?
        var lastWatchedProgress: WatchProgress?

        for (index, episode) in sortedEpisodes.enumerated() {
            if let progress = watchProgressMap[episode.id] {
                lastWatchedIndex = index
                lastWatchedProgress = progress
            }
        }

        // No progress at all - no continue watching button
        guard let lastIndex = lastWatchedIndex, let progress = lastWatchedProgress else {
            return nil
        }

        // If the last watched episode is completed (>= 90%), return the next episode
        if progress.isCompleted {
            let nextIndex = lastIndex + 1
            if nextIndex < sortedEpisodes.count {
                return sortedEpisodes[nextIndex]
            }
            // All episodes completed - no continue watching
            return nil
        }

        // Return the episode that's in progress
        return sortedEpisodes[lastIndex]
    }

    private func continueWatchingButton(episode: Episode) -> some View {
        Button {
            selectedEpisode = episode
        } label: {
            HStack(spacing: .spacingM) {
                // Play icon
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.accentColor)

                // Text content
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
            // Cover image
            AsyncImage(url: anime.coverURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
            }
            .frame(width: 80, height: 120)
            .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusS))

            // Info
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
            // Collapsible header
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

            // Episodes list (shown when expanded)
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
        let progress = watchProgressMap[episode.id]
        
        return VStack(alignment: .leading, spacing: .spacingXS) {
            HStack(spacing: .spacingS) {
                // Episode number badge
                Text("\(episode.number)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 32)
                    .background(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusXS))

                // Episode title and progress info
                VStack(alignment: .leading, spacing: .spacingXXS) {
                    Text(episodeTitle(for: episode))
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    // Progress text if available
                    if let progress, !progress.isCompleted {
                        Text("\(Int((1 - progress.progress) * 100)) % left")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Checkmark for completed episodes
                if let progress, progress.isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.body)
                        .foregroundStyle(.green)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            // Progress bar if episode has been partially watched
            if let progress, !progress.isCompleted, progress.progress > 0 {
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


    //#################################################################################
    // MARK: - Private Methods
    //#################################################################################

    private func loadWatchProgress() {
        let allProgress = watchProgressService.getAllProgress(animeId: viewModel.aniListAnime.id)
        var progressMap: [String: WatchProgress] = [:]
        for progress in allProgress {
            progressMap[progress.episodeId] = progress
        }
        watchProgressMap = progressMap
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
                // Background track
                RoundedRectangle(cornerRadius: Constants.barHeight / 2)
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: Constants.barHeight)

                // Progress fill
                RoundedRectangle(cornerRadius: Constants.barHeight / 2)
                    .fill(Color.accentColor)
                    .frame(width: geometry.size.width * progress, height: Constants.barHeight)
            }
        }
        .frame(height: Constants.barHeight)
    }
}
