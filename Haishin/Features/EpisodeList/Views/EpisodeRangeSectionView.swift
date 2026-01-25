//
//  EpisodeRangeSectionView.swift
//  Haishin
//
//  Created by Haishin on 25.01.26.
//

import SwiftUI


//#################################################################################
// MARK: - EpisodeRangeSectionView
//#################################################################################

/// A collapsible section view for a range of episodes.
struct EpisodeRangeSectionView: View {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    private let range: EpisodeRange
    private let isExpanded: Bool
    private let watchProgressMap: [String: WatchProgress]
    private let onToggle: () -> Void
    private let getDownloadState: (String) -> DownloadState?
    private let onEpisodeTap: (Episode) -> Void
    private let onDownload: (Episode) -> Void
    private let onCancelDownload: (String) -> Void


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new episode range section view.
    /// - Parameters:
    ///   - range: The episode range to display.
    ///   - isExpanded: Whether the section is currently expanded.
    ///   - watchProgressMap: Map of episode IDs to their watch progress.
    ///   - onToggle: Action to perform when the section header is tapped.
    ///   - getDownloadState: Closure to get download state for an episode ID.
    ///   - onEpisodeTap: Action to perform when an episode is tapped.
    ///   - onDownload: Action to perform when download is requested for an episode.
    ///   - onCancelDownload: Action to perform when download is cancelled.
    init(range: EpisodeRange,
         isExpanded: Bool,
         watchProgressMap: [String: WatchProgress],
         onToggle: @escaping () -> Void,
         getDownloadState: @escaping (String) -> DownloadState?,
         onEpisodeTap: @escaping (Episode) -> Void,
         onDownload: @escaping (Episode) -> Void,
         onCancelDownload: @escaping (String) -> Void) {
        self.range = range
        self.isExpanded = isExpanded
        self.watchProgressMap = watchProgressMap
        self.onToggle = onToggle
        self.getDownloadState = getDownloadState
        self.onEpisodeTap = onEpisodeTap
        self.onDownload = onDownload
        self.onCancelDownload = onCancelDownload
    }


    //#################################################################################
    // MARK: - Body
    //#################################################################################

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerButton
            
            if isExpanded {
                episodesList
            }
        }
    }


    //#################################################################################
    // MARK: - Private Views
    //#################################################################################

    private var headerButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                onToggle()
            }
        } label: {
            HStack {
                Text(range.title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                Text("\(range.episodes.count) ep")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
            .padding(.vertical, .spacingXS)
            .padding(.horizontal, .spacingS)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusS))
        }
        .buttonStyle(.plain)
    }

    private var episodesList: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(range.episodes) { episode in
                EpisodeRowView(episode: episode,
                               progress: watchProgressMap[episode.id],
                               downloadState: getDownloadState(episode.id),
                               onTap: { onEpisodeTap(episode) },
                               onDownload: { onDownload(episode) },
                               onCancelDownload: { onCancelDownload(episode.id) })

                if episode.id != range.episodes.last?.id {
                    Divider()
                        .padding(.leading, .spacingS)
                }
            }
        }
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusS))
        .padding(.top, .spacingXS)
    }
}
