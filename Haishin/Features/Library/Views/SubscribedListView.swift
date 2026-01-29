//
//  SubscribedListView.swift
//  Haishin
//
//  Created by Tan Nghia La on 24.01.26.
//

import SwiftUI


//#################################################################################
// MARK: - SubscribedListView
//#################################################################################

/// A list view displaying subscribed videos.
struct SubscribedListView: View {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    @Bindable private var viewModel: LibraryViewModel
    @State private var tappedVideo: SubscribedVideo?
    @State private var selectedViewModel: EpisodeListViewModel?
    @State private var showNoSourceAlert = false


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new subscribed list view.
    /// - Parameter viewModel: The library view model.
    init(viewModel: LibraryViewModel) {
        self.viewModel = viewModel
    }


    //#################################################################################
    // MARK: - Body
    //#################################################################################

    var body: some View {
        Group {
            if viewModel.subscribedVideo.isEmpty {
                ContentUnavailableView {
                    Label("No Subscriptions", systemImage: "bell")
                } description: {
                    Text("Videos you subscribe to will appear here.")
                }
            } else {
                List {
                    ForEach(viewModel.subscribedVideo) { video in
                        VideoRowButton(mode: .subscribed(video),
                                       sourceName: viewModel.sourceName(for: video.sourceId),
                                       item: video) { tappedVideo = $0 }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            let video = viewModel.subscribedVideo[index]
                            viewModel.unsubscribe(id: video.id)
                        }
                    }
                }
                .navigationDestination(item: $selectedViewModel) { episodeViewModel in
                    EpisodeListView(viewModel: episodeViewModel)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Subscribed")
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
            Text("The source used for this subscription is no longer installed. Please reinstall the source or subscribe again with a different source.")
        }
    }
}
