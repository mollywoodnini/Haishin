//
//  AnimeListView.swift
//  Miru
//
//  Created by Miru on 24.01.26.
//

import Kingfisher
import SwiftUI


//#################################################################################
// MARK: - AnimeListView
//#################################################################################

/// A view showing a full list of anime with infinite scroll pagination.
struct AnimeListView: View {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    @State private var viewModel: AnimeListViewModel


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new anime list view.
    /// - Parameters:
    ///   - title: The title of the list.
    ///   - listType: The type of anime list to display.
    init(title: String, listType: AnimeListType) {
        self._viewModel = State(initialValue: AnimeListViewModel(title: title, listType: listType))
    }


    //#################################################################################
    // MARK: - Body
    //#################################################################################

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.items.isEmpty {
                loadingView
            } else if let error = viewModel.error, viewModel.items.isEmpty {
                errorView(error: error)
            } else {
                animeList
            }
        }
        .navigationTitle(viewModel.title)
        .navigationBarTitleDisplayMode(.large)
        .task {
            await viewModel.loadInitialContent()
        }
        .refreshable {
            await viewModel.refresh()
        }
    }


    //#################################################################################
    // MARK: - Subviews
    //#################################################################################

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
            Spacer()
        }
    }

    private func errorView(error: Error) -> some View {
        ContentUnavailableView {
            Label("Failed to Load", systemImage: "exclamationmark.triangle")
        } description: {
            Text(error.localizedDescription)
        } actions: {
            Button("Retry") {
                Task {
                    await viewModel.loadInitialContent()
                }
            }
        }
    }

    private var animeList: some View {
        ScrollView {
            LazyVStack(spacing: .spacingS) {
                ForEach(viewModel.items) { item in
                    NavigationLink {
                        AnimeDetailView(item: item,
                                        subscriptionService: SubscriptionService.shared,
                                        watchProgressService: WatchProgressService.shared,
                                        sourceManager: SourceManager.shared)
                    } label: {
                        AnimeListRow(mode: .general(item))
                    }
                    .buttonStyle(.plain)
                    .onAppear {
                        Task {
                            await viewModel.loadMoreIfNeeded(currentItem: item)
                        }
                    }
                }

                // Loading indicator at the bottom
                if viewModel.isLoadingMore {
                    HStack {
                        Spacer()
                        ProgressView()
                            .padding(.spacingM)
                        Spacer()
                    }
                }
            }
            .padding(.spacingS)
        }
    }
}


//#################################################################################
// MARK: - Preview
//#################################################################################

#Preview {
    NavigationStack {
        AnimeListView(
            title: "Trending",
            listType: .trending
        )
    }
}
