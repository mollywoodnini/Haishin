//
//  AllDownloadedEpisodesView.swift
//  Miru
//
//  Created by Miru on 24.01.26.
//

import SwiftUI


//#################################################################################
// MARK: - AllDownloadedEpisodesView
//#################################################################################

/// A view displaying all downloaded episodes for an anime.
struct AllDownloadedEpisodesView: View {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    private let anime: DownloadedAnime
    @State private var downloadService = DownloadService.shared


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new all downloaded episodes view.
    /// - Parameter anime: The downloaded anime whose episodes to display.
    init(anime: DownloadedAnime) {
        self.anime = anime
    }


    //#################################################################################
    // MARK: - Body
    //#################################################################################

    var body: some View {
        List {
            ForEach(anime.episodes.sorted { $0.episodeNumber < $1.episodeNumber }) { episode in
                episodeRow(episode: episode)
            }
            .onDelete(perform: deleteEpisodes)
        }
        .navigationTitle("Downloaded Episodes")
        .navigationBarTitleDisplayMode(.inline)
    }


    //#################################################################################
    // MARK: - Private Methods
    //#################################################################################

    private func episodeRow(episode: DownloadedEpisode) -> some View {
        HStack(spacing: .spacingS) {
            VStack(alignment: .leading, spacing: .spacingXXS) {
                Text("Episode \(episode.episodeNumber)")
                    .font(.body)

                if let title = episode.episodeTitle {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            downloadStateIndicator(state: episode.state)
        }
    }

    @ViewBuilder
    private func downloadStateIndicator(state: DownloadState) -> some View {
        switch state {
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)

        case .downloading(let progress):
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 2)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 20, height: 20)

        case .pending:
            ProgressView()
                .frame(width: 20, height: 20)

        case .failed:
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.red)

        case .cancelled:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.secondary)
        }
    }

    private func deleteEpisodes(at offsets: IndexSet) {
        let sortedEpisodes = anime.episodes.sorted { $0.episodeNumber < $1.episodeNumber }
        for index in offsets {
            let episode = sortedEpisodes[index]
            downloadService.removeDownload(episodeId: episode.episodeId)
        }
    }
}
