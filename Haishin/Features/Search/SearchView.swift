//
//  SearchView.swift
//  Miru
//
//  Created by Miru on 24.01.26.
//

import SwiftUI

/// The search view for finding anime across sources.
struct SearchView: View {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    @State private var viewModel: SearchViewModel
    @State private var searchText = ""


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new search view.
    /// - Parameter sourceManager: The source manager to use.
    init(sourceManager: SourceManaging) {
        self._viewModel = State(initialValue: SearchViewModel(sourceManager: sourceManager))
    }


    //#################################################################################
    // MARK: - Body
    //#################################################################################

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.results.isEmpty && !viewModel.isSearching {
                    emptyStateView
                } else {
                    resultsView
                }
            }
            .navigationTitle("Search")
            .searchable(text: $searchText, prompt: "Search anime...")
            .onChange(of: searchText) { _, newValue in
                Task {
                    await viewModel.search(query: newValue)
                }
            }
        }
    }


    //#################################################################################
    // MARK: - Subviews
    //#################################################################################

    private var emptyStateView: some View {
        ContentUnavailableView.search
    }

    private var resultsView: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: .spacingS)],
                      spacing: .spacingS) {
                ForEach(viewModel.results) { anime in
                    NavigationLink(value: anime) {
                        SearchResultCard(anime: anime)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.spacingS)
        }
        .overlay {
            if viewModel.isSearching {
                ProgressView()
            }
        }
//        .navigationDestination(for: AnimePreview.self) { anime in
//            AnimeDetailView(anime: anime, sourceManager: sourceManager)
//        }
    }
}


//#################################################################################
// MARK: - SearchResultCard
//#################################################################################

/// A card displaying a search result.
private struct SearchResultCard: View {

    //#################################################################################
    // MARK: - Constants
    //#################################################################################

    private struct Constants {
        static let cardHeight: CGFloat = 200
    }


    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    let anime: AnimePreview


    //#################################################################################
    // MARK: - Body
    //#################################################################################

    var body: some View {
        VStack(alignment: .leading, spacing: .spacingXXS) {
            AsyncImage(url: anime.coverURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    }
            }
            .frame(height: Constants.cardHeight)
            .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusS))

            Text(anime.title)
                .font(.caption)
                .lineLimit(2)
        }
    }
}


//#################################################################################
// MARK: - Preview
//#################################################################################

#Preview {
    SearchView(sourceManager: SourceManager())
}
