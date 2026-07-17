//
//  RecentsListView.swift
//  Haishin
//
//  Created by Tan Nghia La on 24.01.26.
//

import SwiftUI


//#################################################################################
// MARK: - RecentsListView
//#################################################################################

/// A list view displaying recently watched videos.
struct RecentsListView: View {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    @Bindable private var viewModel: LibraryViewModel
    @State private var tappedVideo: RecentVideo?
    @State private var selectedViewModel: EpisodeListViewModel?
    @State private var showNoSourceAlert = false


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new recents list view.
    /// - Parameter viewModel: The library view model.
    init(viewModel: LibraryViewModel) {
        self.viewModel = viewModel
    }


    //#################################################################################
    // MARK: - Body
    //#################################################################################

    var body: some View {
        Group {
            if viewModel.recentVideo.isEmpty {
                ContentUnavailableView {
                    Label("No Recent Videos", systemImage: "clock")
                } description: {
                    Text("Videos you've started watching will appear here.")
                }
            } else {
                List {
                    ForEach(viewModel.recentVideo) { video in
                        VideoRowButton(
                            mode: .recent(video),
                            sourceName: viewModel.sourceName(for: video.sourceId),
                            item: video
                        ) { tappedVideo = $0 }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            let video = viewModel.recentVideo[index]
                            viewModel.removeRecentVideo(id: video.id)
                        }
                    }
                }
                .navigationDestination(item: $selectedViewModel) { episodeViewModel in
                    EpisodeListView(viewModel: episodeViewModel)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Recents")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.refresh()
        }
        .onChange(of: tappedVideo) { _, newValue in
            guard let video = newValue else { return }
            if let episodeViewModel = viewModel.makeEpisodeListViewModel(video: video) {
                selectedViewModel = episodeViewModel
            } else {
                showNoSourceAlert = true
            }
            tappedVideo = nil
        }
        .alert("Source Not Available", isPresented: $showNoSourceAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("The source used for this video is no longer installed. Please reinstall the source.")
        }
    }
}
