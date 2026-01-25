//
//  DownloadedAnimeDetailView.swift
//  Miru
//
//  Created by Miru on 24.01.26.
//

import Kingfisher
import SwiftUI


//#################################################################################
// MARK: - DownloadedAnimeDetailView
//#################################################################################

/// A view displaying downloaded episodes for a specific anime.
struct DownloadedAnimeDetailView: View {

    //#################################################################################
    // MARK: - Constants
    //#################################################################################

    private struct Constants {
        static let coverWidth: CGFloat = 140
    }


    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    private let anime: DownloadedAnime
    @State private var downloadService = DownloadService.shared


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new downloaded anime detail view.
    /// - Parameter anime: The downloaded anime to display.
    init(anime: DownloadedAnime) {
        self.anime = anime
    }


    //#################################################################################
    // MARK: - Body
    //#################################################################################

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: .spacingM) {
                headerView

                inProgressSection

                moreEpisodesSection
            }
            .padding(.spacingM)
        }
        .navigationBarTitleDisplayMode(.inline)
    }


    //#################################################################################
    // MARK: - Subviews
    //#################################################################################

    private var headerView: some View {
        HStack(alignment: .top, spacing: .spacingM) {
            KFImage(anime.coverURL)
                .resizable()
                .placeholder {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.2))
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: Constants.coverWidth, height: Constants.coverWidth * 1.4)
                .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusS))

            VStack(alignment: .leading, spacing: .spacingS) {
                Text(anime.title)
                    .font(.title2.bold())
                    .lineLimit(3)

                Text("\(anime.inProgressCount > 0 ? "\(anime.inProgressCount) in progress" : "\(anime.completedCount) downloaded")")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button {
                    // Navigate to anime detail
                } label: {
                    Text("VIEW ANIME")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, .spacingM)
                        .padding(.vertical, .spacingS)
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusS))
                }
            }

            Spacer()
        }
    }

    private var inProgressSection: some View {
        let inProgressEpisodes = anime.episodes.filter { $0.state.isActive }

        return Group {
            if !inProgressEpisodes.isEmpty {
                VStack(alignment: .leading, spacing: .spacingS) {
                    ForEach(inProgressEpisodes) { episode in
                        downloadedEpisodeRow(episode: episode)
                    }
                }
            }
        }
    }

    private var moreEpisodesSection: some View {
        let completedEpisodes = anime.episodes.filter { $0.state.isCompleted }

        return Group {
            if !completedEpisodes.isEmpty {
                VStack(alignment: .leading, spacing: .spacingS) {
                    NavigationLink {
                        AllDownloadedEpisodesView(anime: anime)
                    } label: {
                        HStack {
                            Text("More Episodes")
                                .font(.headline)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.spacingM)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusS))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func downloadedEpisodeRow(episode: DownloadedEpisode) -> some View {
        VStack(alignment: .leading, spacing: .spacingXS) {
            Text("Download in Progress - \(anime.sourceName)")
                .font(.caption)
                .foregroundStyle(Color.accentColor)

            Text("Episode \(episode.episodeNumber)")
                .font(.headline)

            if case .downloading(let progress) = episode.state {
                HStack(spacing: .spacingS) {
                    ProgressView(value: progress)

                    Text("Downloading (\(Int(progress * 100)) % complete)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()
        }
        .padding(.vertical, .spacingXS)
    }
}
