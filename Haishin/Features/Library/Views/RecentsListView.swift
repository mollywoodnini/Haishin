//
//  RecentsListView.swift
//  Miru
//
//  Created by Miru on 24.01.26.
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
                ScrollView {
                    LazyVStack(spacing: .spacingS) {
                        ForEach(viewModel.recentAnime) { anime in
                            NavigationLink {
                                AnimeDetailView(viewModel: viewModel.makeAnimeDetailViewModel(recentAnime: anime))
                            } label: {
                                AnimeListRow(mode: .recent(anime))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.spacingS)
                }
            }
        }
        .navigationTitle("Recents")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.refresh()
        }
    }
}
