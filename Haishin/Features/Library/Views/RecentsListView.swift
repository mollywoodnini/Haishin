//
//  RecentsListView.swift
//  Haishin
//
//  Created by Haishin on 24.01.26.
//

import SwiftUI


//#################################################################################
// MARK: - RecentsListView
//#################################################################################

/// A list view displaying recently watched anime.
struct RecentsListView: View {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    @Bindable private var viewModel: LibraryViewModel
    @State private var tappedAnime: RecentAnime?


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new recents list view.
    /// - Parameter viewModel: The library view model.
    init(viewModel: LibraryViewModel) {
        self.viewModel = viewModel
    }


    //#################################################################################
    // MARK: - Body
    //#################################################################################

    var body: some View {
        Group {
            if viewModel.recentAnime.isEmpty {
                ContentUnavailableView {
                    Label("No Recent Anime", systemImage: "clock")
                } description: {
                    Text("Anime you've started watching will appear here.")
                }
            } else {
                List {
                    ForEach(viewModel.recentAnime) { anime in
                        AnimeListRowButton(mode: .recent(anime),
                                           item: anime) { tappedAnime = $0 }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            let anime = viewModel.recentAnime[index]
                            viewModel.removeRecentAnime(id: anime.id)
                        }
                    }
                }
                .navigationDestination(item: $tappedAnime) { anime in
                    AnimeDetailView(viewModel: viewModel.makeAnimeDetailViewModel(recentAnime: anime))
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Recents")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.refresh()
        }
    }
}
