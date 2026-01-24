//
//  AnimeDetailView.swift
//  Miru
//
//  Created by Miru on 24.01.26.
//

import SwiftUI

/// Detailed view of an anime showing info and episodes.
struct AnimeDetailView: View {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    @State private var viewModel: AnimeDetailViewModel


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new anime detail view.
    /// - Parameters:
    ///   - anime: The anime preview to show details for.
    ///   - sourceManager: The source manager to use.
    init(anime: AnimePreview, sourceManager: SourceManaging) {
        self._viewModel = State(initialValue: AnimeDetailViewModel(preview: anime,
                                                                    sourceManager: sourceManager))
    }


    //#################################################################################
    // MARK: - Body
    //#################################################################################

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: .spacingM) {
                headerSection

                if let anime = viewModel.anime {
                    infoSection(anime: anime)
                    episodesSection(anime: anime)
                }
            }
        }
        .navigationTitle(viewModel.preview.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadDetails()
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
            }
        }
    }


    //#################################################################################
    // MARK: - Subviews
    //#################################################################################

    private var headerSection: some View {
        ZStack(alignment: .bottom) {
            // Banner or cover as background
            AsyncImage(url: viewModel.anime?.bannerURL ?? viewModel.preview.coverURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
            }
            .frame(height: 200)
            .clipped()

            // Gradient overlay
            LinearGradient(colors: [.clear, .black.opacity(0.7)],
                           startPoint: .top,
                           endPoint: .bottom)

            // Title
            Text(viewModel.preview.title)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .padding(.spacingS)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func infoSection(anime: Anime) -> some View {
        VStack(alignment: .leading, spacing: .spacingS) {
            // Genres
            if !anime.genres.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: .spacingXS) {
                        ForEach(anime.genres, id: \.self) { genre in
                            Text(genre)
                                .font(.caption)
                                .padding(.horizontal, .spacingXS)
                                .padding(.vertical, .spacingXXS)
                                .background(Capsule().fill(.secondary.opacity(0.2)))
                        }
                    }
                }
            }

            // Status and year
            HStack(spacing: .spacingS) {
                Label(anime.status.rawValue.capitalized, systemImage: "clock")
                if let year = anime.year {
                    Label("\(year)", systemImage: "calendar")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            // Synopsis
            if let synopsis = anime.synopsis {
                Text(synopsis)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, .spacingS)
    }

    private func episodesSection(anime: Anime) -> some View {
        VStack(alignment: .leading, spacing: .spacingS) {
            Text("Episodes")
                .font(.title3)
                .fontWeight(.semibold)
                .padding(.horizontal, .spacingS)

            LazyVStack(spacing: .spacingXS) {
                ForEach(anime.episodes) { episode in
                    EpisodeRow(episode: episode) {
                        viewModel.playEpisode(episode)
                    }
                }
            }
        }
    }
}


//#################################################################################
// MARK: - EpisodeRow
//#################################################################################

/// A row displaying an episode.
private struct EpisodeRow: View {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    let episode: Episode
    let onTap: () -> Void


    //#################################################################################
    // MARK: - Body
    //#################################################################################

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: .spacingS) {
                // Thumbnail
                if let thumbnailURL = episode.thumbnailURL {
                    AsyncImage(url: thumbnailURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.2))
                    }
                    .frame(width: 120, height: 68)
                    .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusXS))
                }

                VStack(alignment: .leading, spacing: .spacingXXS) {
                    Text("Episode \(episode.number)")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    if let title = episode.title {
                        Text(title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer()

                Image(systemName: "play.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.tint)
            }
            .padding(.horizontal, .spacingS)
            .padding(.vertical, .spacingXS)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}


//#################################################################################
// MARK: - Preview
//#################################################################################

#Preview {
    NavigationStack {
        AnimeDetailView(anime: AnimePreview(id: "1",
                                            title: "Sample Anime",
                                            coverURL: nil,
                                            sourceId: "test",
                                            detailsURL: "/anime/1"),
                        sourceManager: SourceManager())
    }
}
