//
//  SubscribedListView.swift
//  Haishin
//
//  Created by Tan Nghia La on 24.01.26.
//

import Kingfisher
import SwiftUI


//#################################################################################
// MARK: - SubscribedListView
//#################################################################################

/// A list view displaying subscribed videos.
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
        if viewModel.subscribedVideo.isEmpty, viewModel.subscribedAnime.isEmpty {
            ContentUnavailableView {
                Label("No Subscriptions", systemImage: "bell")
            } description: {
                Text("Videos you subscribe to will appear here.")
            }
            .navigationTitle("Subscribed")
            .navigationBarTitleDisplayMode(.inline)
        } else {
            subscribedList
        }
    }


    //#################################################################################
    // MARK: - Subviews
    //#################################################################################

    @ViewBuilder
    private var subscribedList: some View {
        List {
            if !viewModel.subscribedAnime.isEmpty {
                Section {
                    ForEach(viewModel.subscribedAnime) { anime in
                        NavigationLink {
                            AnimeDetailView(
                                mode: .raw(animeId: anime.id, title: anime.title, coverURL: anime.coverURL),
                                aniListService: AniListService(),
                                subscriptionService: SubscriptionService.shared,
                                watchProgressService: WatchProgressService.shared,
                                sourceManager: SourceManager.shared,
                                userPreferences: UserPreferences.shared
                            )
                        } label: {
                            AnimeSubscriptionRow(anime: anime)
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            let anime = viewModel.subscribedAnime[index]
                            viewModel.unsubscribeAnime(id: anime.id)
                        }
                    }
                } header: {
                    Text("Subscribed Anime")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Subscribed")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.refresh()
        }
    }
}


//#################################################################################
// MARK: - AnimeSubscriptionRow
//#################################################################################

/// A row view for displaying an AniList anime subscription.
private struct AnimeSubscriptionRow: View {

    private let anime: SubscribedAnime

    init(anime: SubscribedAnime) {
        self.anime = anime
    }

    var body: some View {
        HStack(spacing: .spacingS) {
            KFImage(anime.coverURL)
                .resizable()
                .placeholder {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.2))
                        .overlay {
                            Image(systemName: "photo")
                                .foregroundStyle(.secondary)
                        }
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 60, height: 85)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusXS))

            VStack(alignment: .leading, spacing: .spacingXXS) {
                Text(anime.title)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(2)

                Text("AniList")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, .spacingXXS)
    }
}
