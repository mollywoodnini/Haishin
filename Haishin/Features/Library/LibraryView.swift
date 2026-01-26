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
    /// - Parameter downloadService: The download service to use.
    init(watchProgressService: WatchProgressServiceProtocol,
         subscriptionService: SubscriptionServiceProtocol,
         sourceManager: SourceManaging,
         downloadService: DownloadServiceProtocol) {
        self._viewModel = State(initialValue: LibraryViewModel(watchProgressService: watchProgressService,
                                                               subscriptionService: subscriptionService,
                                                               sourceManager: sourceManager,
                                                               downloadService: downloadService))
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
// MARK: - Preview
//#################################################################################

#Preview {
    LibraryView(watchProgressService: WatchProgressService.shared,
                subscriptionService: SubscriptionService.shared,
                sourceManager: SourceManager.shared,
                downloadService: DownloadService.shared)
}
