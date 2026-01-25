//
//  DownloadsListView.swift
//  Miru
//
//  Created by Miru on 24.01.26.
//

import Kingfisher
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
                                DownloadedAnimeDetailView(anime: anime)
                            } label: {
                                DownloadedAnimeRow(anime: anime)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.spacingM)
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


//#################################################################################
// MARK: - DownloadedAnimeRow
//#################################################################################

/// A row displaying a downloaded anime with progress info.
private struct DownloadedAnimeRow: View {

    //#################################################################################
    // MARK: - Constants
    //#################################################################################

    private struct Constants {
        static let coverSize: CGFloat = 100
        static let progressHeight: CGFloat = 4
    }


    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    private let anime: DownloadedAnime


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    init(anime: DownloadedAnime) {
        self.anime = anime
    }


    //#################################################################################
    // MARK: - Body
    //#################################################################################

    var body: some View {
        HStack(spacing: .spacingM) {
            KFImage(anime.coverURL)
                .resizable()
                .placeholder {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.2))
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: Constants.coverSize, height: Constants.coverSize * 1.4)
                .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusS))

            VStack(alignment: .leading, spacing: .spacingXS) {
                Text(anime.title)
                    .font(.headline)
                    .lineLimit(2)

                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                HStack(spacing: .spacingS) {
                    // Progress indicator
                    if anime.inProgressCount > 0 {
                        HStack(spacing: .spacingXXS) {
                            ProgressView(value: anime.averageProgress)
                                .frame(width: 60)

                            Text("\(Int(anime.averageProgress * 100)) %")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, .spacingS)
                        .padding(.vertical, .spacingXXS)
                        .background(Color(.tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusXS))
                    }

                    // Source name
                    Text(anime.sourceName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, .spacingS)
                        .padding(.vertical, .spacingXXS)
                        .background(Color(.tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusXS))
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.spacingM)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusM))
    }

    private var statusText: String {
        if anime.inProgressCount > 0 {
            return "\(anime.inProgressCount) IN PROGRESS"
        } else {
            return "\(anime.completedCount) DOWNLOADED"
        }
    }
}
