//
//  RecentsListView.swift
//  Miru
//
//  Created by Miru on 24.01.26.
//

import Kingfisher
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
                List {
                    ForEach(viewModel.recentAnime) { anime in
                        NavigationLink {
                            AnimeDetailView(viewModel: viewModel.makeAnimeDetailViewModel(recentAnime: anime))
                        } label: {
                            RecentAnimeRow(anime: anime)
                        }
                    }
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


//#################################################################################
// MARK: - RecentAnimeRow
//#################################################################################

/// A row displaying a recently watched anime.
private struct RecentAnimeRow: View {

    //#################################################################################
    // MARK: - Constants
    //#################################################################################

    private struct Constants {
        static let thumbnailSize: CGFloat = 60
    }


    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    private let anime: RecentAnime


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    init(anime: RecentAnime) {
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

                if let episodeNumber = anime.lastEpisodeNumber {
                    Text("Episode \(episodeNumber)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .contentShape(Rectangle())
    }
}
