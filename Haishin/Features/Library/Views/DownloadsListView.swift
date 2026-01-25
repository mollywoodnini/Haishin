//
//  DownloadsListView.swift
//  Miru
//
//  Created by Miru on 24.01.26.
//

import SwiftUI


//#################################################################################
// MARK: - DownloadsListView
//#################################################################################

/// A view displaying all downloaded anime and their episodes.
struct DownloadsListView: View {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    @State private var downloadService = DownloadService.shared
    @State private var isManaging = false


    //#################################################################################
    // MARK: - Body
    //#################################################################################

    var body: some View {
        Group {
            if downloadService.downloadedAnime.isEmpty {
                ContentUnavailableView {
                    Label("No Downloads", systemImage: "arrow.down.circle")
                } description: {
                    Text("Downloaded episodes will appear here.")
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: .spacingM) {
                        ForEach(downloadService.downloadedAnime) { anime in
                            NavigationLink {
                                EpisodeListView(downloadedAnime: anime)
                            } label: {
                                AnimeListRow(mode: .downloaded(anime))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.spacingS)
                }
            }
        }
        .navigationTitle("Downloads")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if !downloadService.downloadedAnime.isEmpty {
                    Button("Manage") {
                        isManaging.toggle()
                    }
                }
            }
        }
    }
}
