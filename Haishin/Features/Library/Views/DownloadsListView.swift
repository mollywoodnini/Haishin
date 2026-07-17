//
//  DownloadsListView.swift
//  Haishin
//
//  Created by Tan Nghia La on 24.01.26.
//

import SwiftUI


//#################################################################################
// MARK: - DownloadsListView
//#################################################################################

/// A view displaying all downloaded videos and their episodes.
struct DownloadsListView: View {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    @Bindable private var viewModel: LibraryViewModel
    @State private var tappedVideo: DownloadedVideo?


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new downloads list view.
    /// - Parameter viewModel: The library view model.
    init(viewModel: LibraryViewModel) {
        self.viewModel = viewModel
    }


    //#################################################################################
    // MARK: - Body
    //#################################################################################

    var body: some View {
        Group {
            if viewModel.downloadedVideo.isEmpty {
                ContentUnavailableView {
                    Label("No Downloads", systemImage: "arrow.down.circle")
                } description: {
                    Text("Downloaded episodes will appear here.")
                }
            } else {
                List {
                    ForEach(viewModel.downloadedVideo) { video in
                        VideoRowButton(
                            mode: .downloaded(video),
                            sourceName: viewModel.sourceName(for: video.sourceId),
                            item: video
                        ) { tappedVideo = $0 }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            let video = viewModel.downloadedVideo[index]
                            viewModel.removeAllDownloads(forVideoId: video.id)
                        }
                    }
                }
                .navigationDestination(item: $tappedVideo) { video in
                    EpisodeListView(viewModel: viewModel.makeEpisodeListViewModel(downloadedVideo: video))
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Downloads")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            viewModel.refresh()
        }
    }
}
