//
//  SubscribedListView.swift
//  Miru
//
//  Created by Miru on 24.01.26.
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
                ScrollView {
                    LazyVStack(spacing: .spacingS) {
                        ForEach(viewModel.subscribedAnime) { anime in
                            NavigationLink {
                                AnimeDetailView(viewModel: viewModel.makeAnimeDetailViewModel(subscribedAnime: anime))
                            } label: {
                                AnimeListRow(mode: .subscribed(anime))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.spacingS)
                }
            }
        }
        .navigationTitle("Subscribed")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.refresh()
        }
    }
}
