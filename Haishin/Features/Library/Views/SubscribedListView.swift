//
//  SubscribedListView.swift
//  Miru
//
//  Created by Miru on 24.01.26.
//

import Kingfisher
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
                List {
                    ForEach(viewModel.subscribedAnime) { anime in
                        NavigationLink {
                            AnimeDetailView(viewModel: viewModel.makeAnimeDetailViewModel(subscribedAnime: anime))
                        } label: {
                            SubscribedAnimeRow(anime: anime)
                        }
                    }
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


//#################################################################################
// MARK: - SubscribedAnimeRow
//#################################################################################

/// A row displaying a subscribed anime.
private struct SubscribedAnimeRow: View {

    //#################################################################################
    // MARK: - Constants
    //#################################################################################

    private struct Constants {
        static let thumbnailSize: CGFloat = 60
    }


    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    private let anime: SubscribedAnime


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    init(anime: SubscribedAnime) {
        self.anime = anime
    }


    //#################################################################################
    // MARK: - Body
    //#################################################################################

    var body: some View {
        HStack(spacing: .spacingS) {
            KFImage(anime.coverURL)
                .resizable()
                .placeholder {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.2))
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: Constants.thumbnailSize, height: Constants.thumbnailSize)
                .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusXS))

            VStack(alignment: .leading, spacing: .spacingXXS) {
                Text(anime.title)
                    .font(.body)
                    .lineLimit(2)
            }

            Spacer()
        }
        .contentShape(Rectangle())
    }
}
