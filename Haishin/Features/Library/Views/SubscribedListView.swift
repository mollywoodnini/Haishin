//
//  SubscribedListView.swift
//  Haishin
//
//  Created by Tan Nghia La on 24.01.26.
//

import SwiftUI


//#################################################################################
// MARK: - SubscribedListView
//#################################################################################

/// A list view displaying subscribed anime.
struct SubscribedListView: View {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    @Bindable private var viewModel: LibraryViewModel
    @State private var tappedAnime: SubscribedAnime?
    @State private var selectedViewModel: EpisodeListViewModel?
    @State private var showNoSourceAlert = false


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new subscribed list view.
    /// - Parameter viewModel: The library view model.
    init(viewModel: LibraryViewModel) {
        self.viewModel = viewModel
    }


    //#################################################################################
    // MARK: - Body
    //#################################################################################

    var body: some View {
        Group {
            if viewModel.subscribedAnime.isEmpty {
                ContentUnavailableView {
                    Label("No Subscriptions", systemImage: "bell")
                } description: {
                    Text("Anime you subscribe to will appear here.")
                }
            } else {
                List {
                    ForEach(viewModel.subscribedAnime) { anime in
                        AnimeRowButton(mode: .subscribed(anime),
                                       sourceName: viewModel.sourceName(for: anime.sourceId),
                                       item: anime) { tappedAnime = $0 }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            let anime = viewModel.subscribedAnime[index]
                            viewModel.unsubscribe(id: anime.id)
                        }
                    }
                }
                .navigationDestination(item: $selectedViewModel) { episodeViewModel in
                    EpisodeListView(viewModel: episodeViewModel)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Subscribed")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.refresh()
        }
        .onChange(of: tappedAnime) { _, newValue in
            guard let anime = newValue else { return }
            if let episodeViewModel = viewModel.makeEpisodeListViewModel(anime: anime) {
                selectedViewModel = episodeViewModel
            } else {
                showNoSourceAlert = true
            }
            tappedAnime = nil
        }
        .alert("Source Not Available", isPresented: $showNoSourceAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("The source used for this subscription is no longer installed. Please reinstall the source or subscribe again with a different source.")
        }
    }
}
