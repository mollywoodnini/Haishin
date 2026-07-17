//
//  SourceDetailView.swift
//  Haishin
//
//  Created by Claude on 29.01.26.
//

import SwiftUI


//#################################################################################
// MARK: - SourceDetailView
//#################################################################################

/// View displaying videos from an installed source in a grid layout.
struct SourceDetailView: View {

    //#################################################################################
    // MARK: - Constants
    //#################################################################################

    private struct Constants {
        static let columnCount = 2
        static let imageAspectRatio: CGFloat = 2 / 3
        static let titleLineLimit = 2
    }


    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    @State private var viewModel: SourceDetailViewModel


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new source detail view.
    /// - Parameters:
    ///   - source: The installed source to display.
    ///   - sourceManager: The source manager to use.
    ///   - watchProgressService: The service for accessing watch progress.
    ///   - subscriptionService: The service for managing subscriptions.
    ///   - downloadService: The service for managing downloads.
    init(
        source: InstalledSource,
        sourceManager: SourceManaging,
        watchProgressService: WatchProgressServiceProtocol,
        subscriptionService: SubscriptionServiceProtocol,
        downloadService: DownloadServiceProtocol
    ) {
        self._viewModel = State(
            initialValue: SourceDetailViewModel(
                source: source,
                sourceManager: sourceManager,
                watchProgressService: watchProgressService,
                subscriptionService: subscriptionService,
                downloadService: downloadService
            )
        )
    }


    //#################################################################################
    // MARK: - Body
    //#################################################################################

    var body: some View {
        ScrollView {
            if viewModel.isLoading {
                loadingView
            } else if let error = viewModel.error {
                errorView(error: error)
            } else if viewModel.videos.isEmpty {
                emptyView
            } else {
                videoGrid
            }
        }
        .refreshable {
            await viewModel.loadContent(forceRefresh: true)
        }
        .navigationTitle(viewModel.source.info.name)
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(for: VideoPreview.self) { video in
            EpisodeListView(viewModel: viewModel.makeEpisodeListViewModel(for: video))
        }
        .task {
            await viewModel.loadContent()
        }
    }


    //#################################################################################
    // MARK: - Subviews
    //#################################################################################

    private var videoGrid: some View {
        let columns = Array(
            repeating: GridItem(.flexible(), spacing: .spacingS),
            count: Constants.columnCount
        )

        return LazyVGrid(columns: columns, spacing: .spacingS) {
            ForEach(viewModel.videos) { video in
                NavigationLink(value: video) {
                    VideoCard(videoPreview: video)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.spacingS)
    }

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }

    private func errorView(error: Error) -> some View {
        VStack(spacing: .spacingM) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Failed to load videos")
                .font(.headline)
            Text(error.localizedDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Try Again") {
                Task {
                    await viewModel.loadContent(forceRefresh: true)
                }
            }
            .buttonStyle(.bordered)
            Spacer()
        }
        .padding(.horizontal, .spacingL)
        .frame(maxWidth: .infinity, minHeight: 300)
    }

    private var emptyView: some View {
        VStack(spacing: .spacingM) {
            Spacer()
            Image(systemName: "film")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No videos available")
                .font(.headline)
            Text("This source doesn't have any videos yet.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }
}
