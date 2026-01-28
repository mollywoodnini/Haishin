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
    @State private var selectedViewModel: EpisodeListViewModel?
    @State private var showNoSourceAlert = false


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
                        AnimeRowButton(mode: .recent(anime),
                                       item: anime) { tappedAnime = $0 }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            let anime = viewModel.recentAnime[index]
                            viewModel.removeRecentAnime(id: anime.id)
                        }
                    }
                }
                .navigationDestination(item: $selectedViewModel) { episodeViewModel in
                    EpisodeListView(viewModel: episodeViewModel)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Recents")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.refresh()
        }
        .onChange(of: tappedAnime) { _, newValue in
            guard let anime = newValue else { return }
            if let episodeViewModel = viewModel.makeEpisodeListViewModel(recentAnime: anime) {
                selectedViewModel = episodeViewModel
            } else {
                showNoSourceAlert = true
            }
            tappedAnime = nil
        }
        .alert("No Source Selected", isPresented: $showNoSourceAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please select a source in Settings before viewing episodes.")
        }
    }
}
