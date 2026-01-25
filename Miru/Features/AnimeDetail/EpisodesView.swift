//
//  EpisodesView.swift
//  Miru
//
//  Created by Miru on 24.01.26.
//

import SwiftUI


//#################################################################################
// MARK: - EpisodesView
//#################################################################################

/// View for displaying episodes from a JavaScript source.
struct EpisodesView: View {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    @State private var viewModel: EpisodesViewModel
    @Environment(\.dismiss) private var dismiss


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new episodes view.
    /// - Parameters:
    ///   - aniListAnime: The AniList anime details.
    ///   - sourceId: The selected source ID.
    init(aniListAnime: AniListAnimeDetail, sourceId: String) {
        self._viewModel = State(initialValue: EpisodesViewModel(aniListAnime: aniListAnime,
                                                                  sourceId: sourceId))
    }


    //#################################################################################
    // MARK: - Body
    //#################################################################################

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.sourceAnime == nil {
                loadingView
            } else if let error = viewModel.error {
                errorView(error: error)
            } else if let anime = viewModel.sourceAnime {
                episodesListView(anime: anime)
            }
        }
        .navigationTitle("Episodes")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadEpisodes()
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
        VStack(spacing: .spacingM) {
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

            Button("Retry") {
                Task {
                    await viewModel.retry()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }


    //#################################################################################
    // MARK: - Episodes List View
    //#################################################################################

    private func episodesListView(anime: Anime) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: .spacingM) {
                // Header with anime info
                animeHeaderView(anime: anime)

                // Episodes grid
                episodesGridView(episodes: anime.episodes)
            }
            .padding(.spacingM)
        }
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
    // MARK: - Episodes Grid View
    //#################################################################################

    private func episodesGridView(episodes: [Episode]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: .spacingS)],
                  spacing: .spacingS) {
            ForEach(episodes) { episode in
                episodeCardView(episode: episode)
            }
        }
    }


    //#################################################################################
    // MARK: - Episode Card View
    //#################################################################################

    private func episodeCardView(episode: Episode) -> some View {
        VStack(alignment: .leading, spacing: .spacingXS) {
            // Thumbnail or placeholder
            ZStack {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .aspectRatio(16/9, contentMode: .fit)

                // Episode number overlay
                VStack {
                    Spacer()
                    HStack {
                        Text("EP \(episode.number)")
                            .font(.caption2.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, .spacingXS)
                            .padding(.vertical, 4)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        Spacer()
                    }
                    .padding(.spacingXS)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusXS))

            // Episode title
            if let title = episode.title {
                Text(title)
                    .font(.caption)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .onTapGesture {
            // TODO: Navigate to video player
            print("Tapped episode: \(episode.number)")
        }
    }
}
