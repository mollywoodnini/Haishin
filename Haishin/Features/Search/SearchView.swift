//
//  SearchView.swift
//  Haishin
//
//  Created by Tan Nghia La on 24.01.26.
//

import SwiftUI

/// The search view for finding videos across sources.
struct SearchView: View {

    //#################################################################################
    // MARK: - Constants
    //#################################################################################

    private struct Constants {
        static let cardWidth: CGFloat = 140
        static let loadingPlaceholderCount: Int = 3
        static let loadingPlaceholderHeight: CGFloat = 200
        static let stateViewHeight: CGFloat = 60
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
    /// - Parameters:
    ///   - sourceManager: The source manager to use.
    ///   - watchProgressService: The service for accessing watch progress.
    ///   - subscriptionService: The service for managing subscriptions.
    ///   - downloadService: The service for managing downloads.
    init(sourceManager: SourceManaging,
         watchProgressService: WatchProgressServiceProtocol,
         subscriptionService: SubscriptionServiceProtocol,
         downloadService: DownloadServiceProtocol) {
        self._viewModel = State(initialValue: SearchViewModel(sourceManager: sourceManager,
                                                              watchProgressService: watchProgressService,
                                                              subscriptionService: subscriptionService,
                                                              downloadService: downloadService))
    }


    //#################################################################################
    // MARK: - Body
    //#################################################################################

    var body: some View {
        NavigationStack {
            Group {
                if searchText.isEmpty && !viewModel.recentSearches.isEmpty {
                    recentSearchesView
                } else if viewModel.sourceStates.isEmpty {
                    emptyStateView
                } else {
                    resultsView
                }
            }
            .navigationTitle("Search")
            .searchable(text: $searchText, prompt: "Search videos...")
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

    private var resultsView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: .spacingL) {
                ForEach(viewModel.sourceStates) { state in
                    sourceSectionView(state)
                }
            }
            .padding(.vertical, .spacingS)
        }
        .navigationDestination(for: VideoPreview.self) { video in
            EpisodeListView(viewModel: viewModel.makeEpisodeListViewModel(for: video))
        }
    }

    private func sourceSectionView(_ state: SourceSearchState) -> some View {
        VStack(alignment: .leading, spacing: .spacingS) {
            Text(state.sourceName)
                .font(.headline)
                .padding(.horizontal, .spacingM)

            if state.isLoading {
                loadingCardsView
            } else if state.error != nil {
                errorView(for: state)
            } else if state.results.isEmpty {
                noResultsView
            } else {
                resultsCardsView(for: state)
            }
        }
    }

    private var loadingCardsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: .spacingS) {
                ForEach(0..<Constants.loadingPlaceholderCount, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: .cornerRadiusS)
                        .fill(Color(.tertiarySystemFill))
                        .frame(width: Constants.cardWidth, height: Constants.loadingPlaceholderHeight)
                        .overlay {
                            ProgressView()
                        }
                }
            }
            .padding(.horizontal, .spacingM)
        }
    }

    private func errorView(for state: SourceSearchState) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.secondary)
            Text("Failed to search")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, .spacingM)
        .frame(height: Constants.stateViewHeight)
    }

    private var noResultsView: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            Text("No results")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, .spacingM)
        .frame(height: Constants.stateViewHeight)
    }

    private func resultsCardsView(for state: SourceSearchState) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: .spacingS) {
                ForEach(state.results) { video in
                    NavigationLink(value: video) {
                        VideoCard(videoPreview: video, sizingMode: .fixed)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, .spacingM)
        }
    }
}


//#################################################################################
// MARK: - Preview
//#################################################################################

#Preview {
    SearchView(sourceManager: SourceManager(),
               watchProgressService: WatchProgressService.shared,
               subscriptionService: SubscriptionService.shared,
               downloadService: DownloadService.shared)
}
