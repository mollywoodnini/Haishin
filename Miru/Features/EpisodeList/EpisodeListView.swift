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
    @State private var selectedVideoSource: VideoSource?
    @State private var mirrorActionEpisode: Episode?
    @State private var availableMirrors: [VideoSource] = []
    @State private var isLoadingMirrors = false
    @State private var showingMirrorSheet = false

    private let sourceManager: SourceManager


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new episodes view.
    /// - Parameters:
    ///   - aniListAnime: The AniList anime details.
    ///   - sourceId: The selected source ID.
    ///   - sourceManager: The shared source manager.
    init(aniListAnime: AniListAnimeDetail, sourceId: String, sourceManager: SourceManager) {
        print("[EpisodeListView] init called for anime: '\(aniListAnime.title)', sourceId: '\(sourceId)'")
        self.sourceManager = sourceManager
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
                Button("Change Source") {
                    showingSourcePicker = true
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
        }
        .fullScreenCover(item: $selectedEpisode) { episode in
            VideoPlayerView(episode: episode,
                            animeTitle: viewModel.aniListAnime.title,
                            sourceId: viewModel.sourceId,
                            sourceManager: sourceManager,
                            preselectedSource: selectedVideoSource)
        }
        .onChange(of: selectedEpisode) { _, newValue in
            // Reset selected video source when episode changes (unless coming from mirror selection)
            if newValue == nil {
                selectedVideoSource = nil
            }
        }
        .confirmationDialog("Select Mirror",
                            isPresented: $showingMirrorSheet,
                            titleVisibility: .visible) {
            ForEach(availableMirrors) { mirror in
                Button(mirror.quality ?? mirror.serverName) {
                    if let episode = mirrorActionEpisode {
                        selectedVideoSource = mirror
                        selectedEpisode = episode
                    }
                }
            }
            Button("Cancel", role: .cancel) {
                mirrorActionEpisode = nil
                availableMirrors = []
            }
        } message: {
            if let episode = mirrorActionEpisode {
                Text("Episode \(episode.number)")
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
        HStack(spacing: .spacingS) {
            // Episode number badge
            Text("\(episode.number)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 32)
                .background(Color.accentColor)
                .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusXS))

            // Episode title or default text
            VStack(alignment: .leading, spacing: .spacingXXS) {
                Text(episodeTitle(for: episode))
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }

            Spacer()

            // Show loading indicator when fetching mirrors for this episode
            if isLoadingMirrors && mirrorActionEpisode?.id == episode.id {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, .spacingS)
        .padding(.vertical, .spacingXS)
        .contentShape(Rectangle())
        .onTapGesture {
            selectedVideoSource = nil
            selectedEpisode = episode
        }
        .onLongPressGesture {
            fetchMirrors(for: episode)
        }
    }


    //#################################################################################
    // MARK: - Mirror Fetching
    //#################################################################################

    private func fetchMirrors(for episode: Episode) {
        guard !isLoadingMirrors else { return }

        mirrorActionEpisode = episode
        isLoadingMirrors = true

        Task {
            do {
                let playbackInfo = try await sourceManager.getVideoSources(sourceId: viewModel.sourceId,
                                                                            episodeId: episode.id,
                                                                            url: episode.url)
                await MainActor.run {
                    availableMirrors = playbackInfo.sources
                    isLoadingMirrors = false

                    if availableMirrors.isEmpty {
                        mirrorActionEpisode = nil
                    } else {
                        showingMirrorSheet = true
                    }
                }
            } catch {
                await MainActor.run {
                    isLoadingMirrors = false
                    mirrorActionEpisode = nil
                    print("[EpisodeListView] Error fetching mirrors: \(error)")
                }
            }
        }
    }
}
