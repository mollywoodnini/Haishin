//
//  LibraryView.swift
//  Miru
//
//  Created by Miru on 24.01.26.
//

import SwiftUI


//#################################################################################
// MARK: - LibraryView
//#################################################################################

/// The library view showing recents, subscribed anime, and downloads.
struct LibraryView: View {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    @State private var viewModel: LibraryViewModel


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new library view.
    /// - Parameter watchProgressService: The watch progress service to use.
    /// - Parameter subscriptionService: The subscription service to use.
    /// - Parameter sourceManager: The source manager to use.
    init(watchProgressService: WatchProgressServiceProtocol,
         subscriptionService: SubscriptionServiceProtocol,
         sourceManager: SourceManaging) {
        self._viewModel = State(initialValue: LibraryViewModel(watchProgressService: watchProgressService,
                                                               subscriptionService: subscriptionService,
                                                               sourceManager: sourceManager))
    }


    //#################################################################################
    // MARK: - Body
    //#################################################################################

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: .spacingM) {
                    // Top row: Recents and Subscribed
                    HStack(spacing: .spacingS) {
                        NavigationLink {
                            RecentsListView(viewModel: viewModel)
                        } label: {
                            LibraryCard(icon: "clock.fill",
                                        title: "Recents",
                                        count: viewModel.recentsCount,
                                        color: .blue)
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            SubscribedListView(viewModel: viewModel)
                        } label: {
                            LibraryCard(icon: "bell.fill",
                                        title: "Subscribed",
                                        count: viewModel.subscribedCount,
                                        color: .orange)
                        }
                        .buttonStyle(.plain)
                    }

                    // Bottom row: Downloads
                    NavigationLink {
                        DownloadsListView()
                    } label: {
                        LibraryWideCard(icon: "arrow.down.circle.fill",
                                        title: "Downloads",
                                        count: viewModel.downloadsCount,
                                        color: .green)
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
                .padding(.spacingS)
            }
            .navigationTitle("Library")
            .onAppear {
                viewModel.refresh()
            }
        }
    }
}


//#################################################################################
// MARK: - LibraryCard
//#################################################################################

/// A square card for library categories.
private struct LibraryCard: View {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    let icon: String
    let title: String
    let count: Int
    let color: Color


    //#################################################################################
    // MARK: - Body
    //#################################################################################

    var body: some View {
        VStack(alignment: .leading, spacing: .spacingXS) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Spacer()

            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                Text("\(count)")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.spacingS)
        .frame(maxWidth: .infinity, minHeight: 100)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusM))
    }
}


//#################################################################################
// MARK: - LibraryWideCard
//#################################################################################

/// A wide card for library categories (spanning full width).
private struct LibraryWideCard: View {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    let icon: String
    let title: String
    let count: Int
    let color: Color


    //#################################################################################
    // MARK: - Body
    //#################################################################################

    var body: some View {
        HStack(spacing: .spacingS) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)

            Spacer()

            Text("\(count)")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.spacingS)
        .frame(maxWidth: .infinity, minHeight: 56)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusM))
    }
}


//#################################################################################
// MARK: - RecentsListView
//#################################################################################

/// A list view displaying recently watched anime.
struct RecentsListView: View {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    @Bindable var viewModel: LibraryViewModel


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

    let anime: RecentAnime


    //#################################################################################
    // MARK: - Body
    //#################################################################################

    var body: some View {
        HStack(spacing: .spacingS) {
            AsyncImage(url: anime.coverURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
            }
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


//#################################################################################
// MARK: - SubscribedListView
//#################################################################################

/// A list view displaying subscribed anime.
struct SubscribedListView: View {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    @Bindable var viewModel: LibraryViewModel


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

    let anime: SubscribedAnime


    //#################################################################################
    // MARK: - Body
    //#################################################################################

    var body: some View {
        HStack(spacing: .spacingS) {
            AsyncImage(url: anime.coverURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
            }
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


//#################################################################################
// MARK: - DownloadsListView
//#################################################################################

/// A placeholder view for downloads (not yet implemented).
struct DownloadsListView: View {

    //#################################################################################
    // MARK: - Body
    //#################################################################################

    var body: some View {
        ContentUnavailableView {
            Label("No Downloads", systemImage: "arrow.down.circle")
        } description: {
            Text("Downloaded episodes will appear here.")
        }
        .navigationTitle("Downloads")
        .navigationBarTitleDisplayMode(.inline)
    }
}


//#################################################################################
// MARK: - Preview
//#################################################################################

#Preview {
    LibraryView(watchProgressService: WatchProgressService.shared,
                subscriptionService: SubscriptionService.shared,
                sourceManager: SourceManager.shared)
}
