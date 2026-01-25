//
//  AnimeListView.swift
//  Miru
//
//  Created by Miru on 24.01.26.
//

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
                                        watchProgressService: WatchProgressService.shared)
                    } label: {
                        AnimeListRow(item: item)
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
// MARK: - AnimeListRow
//#################################################################################

/// A row showing an anime in the list view.
private struct AnimeListRow: View {

    //#################################################################################
    // MARK: - Constants
    //#################################################################################

    private struct Constants {
        static let imageWidth: CGFloat = 85
        static let rowHeight: CGFloat = 120
    }


    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    let item: RecommendingItem


    //#################################################################################
    // MARK: - Body
    //#################################################################################

    var body: some View {
        HStack(spacing: .spacingS) {
            // Cover image with badge - flush to edges
            ZStack(alignment: .bottomLeading) {
                AsyncImage(url: item.coverURL) { image in
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
                .frame(width: Constants.imageWidth, height: Constants.rowHeight)
                .clipped()
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: .cornerRadiusM,
                        bottomLeadingRadius: .cornerRadiusM,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: 0
                    )
                )

                // Episode badge
                if let caption = item.caption {
                    Text(caption)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, .spacingXS)
                        .padding(.vertical, 2)
                        .background(.black.opacity(0.7))
                        .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusXS))
                        .padding(.spacingXXS)
                } else if let totalEpisodes = item.totalEpisodes {
                    Text("\(totalEpisodes) ep")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, .spacingXS)
                        .padding(.vertical, 2)
                        .background(.black.opacity(0.7))
                        .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusXS))
                        .padding(.spacingXXS)
                }
            }

            // Info
            VStack(alignment: .leading, spacing: .spacingXXS) {
                Text(item.title)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(2)

                if let subtitle = item.subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if let synopsis = item.synopsis {
                    Text(synopsis)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, .spacingS)
            .padding(.trailing, .spacingS)
        }
        .frame(height: Constants.rowHeight)
        .background(Color.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusM))
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
