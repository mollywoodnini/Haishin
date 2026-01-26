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

    @Bindable private var viewModel: LibraryViewModel
    @State private var tappedAnime: DownloadedAnime?


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new downloads list view.
    /// - Parameter viewModel: The library view model.
    init(viewModel: LibraryViewModel) {
        self.viewModel = viewModel
    }


    //#################################################################################
    // MARK: - Body
    //#################################################################################

    var body: some View {
        Group {
            if viewModel.downloadedAnime.isEmpty {
                ContentUnavailableView {
                    Label("No Downloads", systemImage: "arrow.down.circle")
                } description: {
                    Text("Downloaded episodes will appear here.")
                }
            } else {
                List {
                    ForEach(viewModel.downloadedAnime) { anime in
                        AnimeListRowButton(mode: .downloaded(anime),
                                           item: anime) { tappedAnime = $0 }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            let anime = viewModel.downloadedAnime[index]
                            viewModel.removeAllDownloads(forAnimeId: anime.id)
                        }
                    }
                }
                .navigationDestination(item: $tappedAnime) { anime in
                    EpisodeListView(viewModel: viewModel.makeEpisodeListViewModel(downloadedAnime: anime))
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Downloads")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            viewModel.refresh()
        }
    }
}
