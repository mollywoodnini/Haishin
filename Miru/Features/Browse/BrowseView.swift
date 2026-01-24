//
//  BrowseView.swift
//  Miru
//
//  Created by Miru on 24.01.26.
//

import SwiftUI

/// The main browse view showing anime from installed sources.
struct BrowseView: View {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    @State private var viewModel: BrowseViewModel
    private let sourceManager: SourceManaging


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new browse view.
    /// - Parameter sourceManager: The source manager to use.
    init(sourceManager: SourceManaging) {
        self.sourceManager = sourceManager
        self._viewModel = State(initialValue: BrowseViewModel(sourceManager: sourceManager))
    }


    //#################################################################################
    // MARK: - Body
    //#################################################################################

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.installedSources.isEmpty {
                    emptyStateView
                } else {
                    contentView
                }
            }
            .navigationTitle("Browse")
            .task {
                await viewModel.loadContent()
            }
            .refreshable {
                await viewModel.refresh()
            }
        }
    }


    //#################################################################################
    // MARK: - Subviews
    //#################################################################################

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Sources", systemImage: "globe.badge.chevron.backward")
        } description: {
            Text("Add sources from the Sources tab to start browsing anime.")
        }
    }

    private var contentView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: .spacingM) {
                if !viewModel.popularAnime.isEmpty {
                    AnimeSection(title: "Popular",
                                 anime: viewModel.popularAnime,
                                 sourceManager: sourceManager)
                }

                if !viewModel.latestAnime.isEmpty {
                    AnimeSection(title: "Latest",
                                 anime: viewModel.latestAnime,
                                 sourceManager: sourceManager)
                }
            }
            .padding(.horizontal, .spacingS)
        }
        .overlay {
            if viewModel.isLoading && viewModel.popularAnime.isEmpty {
                ProgressView()
            }
        }
    }
}


//#################################################################################
// MARK: - AnimeSection
//#################################################################################

/// A horizontal section displaying anime previews.
private struct AnimeSection: View {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    let title: String
    let anime: [AnimePreview]
    let sourceManager: SourceManaging


    //#################################################################################
    // MARK: - Body
    //#################################################################################

    var body: some View {
        VStack(alignment: .leading, spacing: .spacingXS) {
            Text(title)
                .font(.title2)
                .fontWeight(.bold)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: .spacingS) {
                    ForEach(anime) { item in
                        NavigationLink(value: item) {
                            AnimeCard(anime: item)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .navigationDestination(for: AnimePreview.self) { anime in
            AnimeDetailView(anime: anime, sourceManager: sourceManager)
        }
    }
}


//#################################################################################
// MARK: - AnimeCard
//#################################################################################

/// A card view displaying an anime preview.
private struct AnimeCard: View {

    //#################################################################################
    // MARK: - Constants
    //#################################################################################

    private struct Constants {
        static let cardWidth: CGFloat = 140
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
            .frame(width: Constants.cardWidth, height: Constants.cardHeight)
            .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusS))

            Text(anime.title)
                .font(.caption)
                .lineLimit(2)
                .frame(width: Constants.cardWidth, alignment: .leading)
        }
    }
}


//#################################################################################
// MARK: - Preview
//#################################################################################

#Preview {
    BrowseView(sourceManager: SourceManager())
}
