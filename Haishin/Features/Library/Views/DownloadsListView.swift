//
//  DownloadsListView.swift
//  Miru
//
//  Created by Miru on 24.01.26.
//

import SwiftUI


//#################################################################################
// MARK: - DownloadsListView
//#################################################################################

/// A view displaying all downloaded anime and their episodes.
struct DownloadsListView: View {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    @State private var downloadService = DownloadService.shared
    @State private var tappedAnime: DownloadedAnime? = nil


    //#################################################################################
    // MARK: - Body
    //#################################################################################

    var body: some View {
        Group {
            if downloadService.downloadedAnime.isEmpty {
                ContentUnavailableView {
                    Label("No Downloads", systemImage: "arrow.down.circle")
                } description: {
                    Text("Downloaded episodes will appear here.")
                }
            } else {
                List {
                    ForEach(downloadService.downloadedAnime) { anime in
                        AnimeListRowButton(mode: .downloaded(anime),
                                           item: anime) { tappedAnime = $0 }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            let anime = downloadService.downloadedAnime[index]
                            downloadService.removeAllDownloads(forAnimeId: anime.id)
                        }
                    }
                }
                .navigationDestination(item: $tappedAnime) { anime in
                    EpisodeListView(downloadedAnime: anime,
                                    watchProgressService: WatchProgressService.shared,
                                    downloadService: DownloadService.shared)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Downloads")
        .navigationBarTitleDisplayMode(.large)
    }
}
