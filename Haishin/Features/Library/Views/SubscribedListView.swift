//
//  SubscribedListView.swift
//  Haishin
//
//  Created by Haishin on 24.01.26.
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
                        AnimeListRowButton(mode: .subscribed(anime),
                                           item: anime) { tappedAnime = $0 }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            let anime = viewModel.subscribedAnime[index]
                            viewModel.unsubscribe(id: anime.id)
                        }
                    }
                }
                .navigationDestination(item: $tappedAnime) { anime in
                    AnimeDetailView(viewModel: viewModel.makeAnimeDetailViewModel(subscribedAnime: anime))
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Subscribed")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.refresh()
        }
    }
}
