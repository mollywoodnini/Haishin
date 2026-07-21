//
//  SearchView.swift
//  Haishin
//
//  Created by Tan Nghia La on 24.01.26.
//

import SwiftUI

/// The search view for finding anime via AniList.
struct SearchView: View {

    //#################################################################################
    // MARK: - Constants
    //#################################################################################

    private enum Constants {
        static let columns = [GridItem(.adaptive(minimum: 140), spacing: .spacingS)]
    }


    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    @State private var viewModel: SearchViewModel
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new search view.
    /// - Parameter aniListService: The AniList service to use.
    init(aniListService: AniListServicing) {
        self._viewModel = State(initialValue: SearchViewModel(aniListService: aniListService))
    }


    //#################################################################################
    // MARK: - Body
    //#################################################################################

    var body: some View {
        NavigationStack {
            Group {
                if searchText.isEmpty && !viewModel.recentSearches.isEmpty {
                    recentSearchesView
                } else if viewModel.isSearching {
                    loadingView
                } else if let error = viewModel.error {
                    errorView(error)
                } else if !viewModel.results.isEmpty {
                    resultsView
                } else if !searchText.isEmpty {
                    emptyResultsView
                } else {
                    emptyStateView
                }
            }
            .navigationTitle("Search")
            .searchable(text: $searchText, prompt: "Search anime...")
            .searchFocused($isSearchFocused)
            .onChange(of: searchText) { _, newValue in
                viewModel.search(query: newValue)
            }
        }
    }


    //#################################################################################
    // MARK: - Subviews
    //#################################################################################

    private var emptyStateView: some View {
        ContentUnavailableView.search
    }

    private var emptyResultsView: some View {
        ContentUnavailableView {
            Label("No Results", systemImage: "magnifyingglass")
        } description: {
            Text("No anime found for \(searchText). Try a different search term.")
        }
    }

    private var loadingView: some View {
        VStack(spacing: .spacingM) {
            ProgressView()
            Text("Searching...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ error: Error) -> some View {
        ContentUnavailableView {
            Label("Search Failed", systemImage: "exclamationmark.magnifyingglass")
        } description: {
            Text(error.localizedDescription)
        } actions: {
            Button("Try Again") {
                viewModel.search(query: searchText)
            }
        }
    }

    private var resultsView: some View {
        ScrollView {
            LazyVGrid(columns: Constants.columns, spacing: .spacingM) {
                ForEach(viewModel.results) { item in
                    NavigationLink {
                        AnimeDetailView(
                            mode: .raw(animeId: item.anilistId, title: item.title, coverURL: item.coverURL),
                            aniListService: AniListService(),
                            subscriptionService: SubscriptionService.shared,
                            watchProgressService: WatchProgressService.shared,
                            sourceManager: SourceManager.shared,
                            userPreferences: UserPreferences.shared
                        )
                    } label: {
                        StandardAnimeCard(item: item, sizingMode: .flexible)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.spacingM)
        }
    }

    private var recentSearchesView: some View {
        List {
            Section {
                ForEach(viewModel.recentSearches, id: \.self) { query in
                    Button {
                        searchText = query
                        viewModel.search(query: query)
                    } label: {
                        HStack {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundStyle(.secondary)
                            Text(query)
                                .foregroundStyle(.primary)
                            Spacer()
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            viewModel.removeFromRecentSearches(query)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            } header: {
                HStack {
                    Text("Recent Searches")
                    Spacer()
                    Button("Clear") {
                        viewModel.clearRecentSearches()
                    }
                    .font(.caption)
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}


//#################################################################################
// MARK: - Preview
//#################################################################################

#Preview {
    SearchView(aniListService: AniListService())
}
