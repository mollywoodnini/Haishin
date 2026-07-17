//
//  VideoRow.swift
//  Haishin
//
//  Created by Tan Nghia La on 28.01.26.
//

import Kingfisher
import SwiftUI


//#################################################################################
// MARK: - VideoRowButton
//#################################################################################

/// A button wrapper for `VideoRow` with list row styling for swipe-to-delete lists.
struct VideoRowButton<T>: View {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    private let mode: VideoRow.Mode
    private let sourceName: String?
    private let item: T
    private let onTap: (T) -> Void


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new `VideoRowButton`.
    /// - Parameters:
    ///   - mode: The display mode for the row.
    ///   - sourceName: Optional source name to display.
    ///   - item: The item associated with this row.
    ///   - onTap: Action to perform when tapped.
    init(mode: VideoRow.Mode, sourceName: String?, item: T, onTap: @escaping (T) -> Void) {
        self.mode = mode
        self.sourceName = sourceName
        self.item = item
        self.onTap = onTap
    }


    //#################################################################################
    // MARK: - Body
    //#################################################################################

    var body: some View {
        Button {
            onTap(item)
        } label: {
            VideoRow(mode: mode, sourceName: sourceName)
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets(
            top: .spacingXS,
            leading: .spacingS,
            bottom: .spacingXS,
            trailing: .spacingS
        ))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }
}


//#################################################################################
// MARK: - VideoRow
//#################################################################################

/// A row showing a video in the list view.
struct VideoRow: View {

    //#################################################################################
    // MARK: - Types
    //#################################################################################

    /// The display mode for the row with associated model data.
    enum Mode {
        /// Recent video display with last watched episode.
        case recent(RecentVideo)
        /// Subscribed video display.
        case subscribed(SubscribedVideo)
        /// Downloaded video display with episode count and progress.
        case downloaded(DownloadedVideo)
    }


    //#################################################################################
    // MARK: - Constants
    //#################################################################################

    private struct Constants {
        static let imageWidth: CGFloat = 85
        static let rowHeight: CGFloat = 120
        static let stateViewHeight: CGFloat = 60
    }


    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    private let mode: Mode
    private let sourceName: String?


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new `VideoRow`.
    /// - Parameter mode: The display mode containing the model data.
    /// - Parameter sourceName: Optional source name to display.
    init(mode: Mode, sourceName: String? = nil) {
        self.mode = mode
        self.sourceName = sourceName
    }


    //#################################################################################
    // MARK: - Body
    //#################################################################################

    var body: some View {
        HStack(spacing: .spacingS) {
            coverImageWithBadge
            infoSection
        }
        .frame(height: Constants.rowHeight)
        .background(Color.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusM))
    }


    //#################################################################################
    // MARK: - Private Computed Properties
    //#################################################################################

    private var coverURL: URL? {
        switch mode {
        case .recent(let video):
            return video.coverURL
        case .subscribed(let video):
            return video.coverURL
        case .downloaded(let video):
            return video.coverURL
        }
    }

    private var title: String {
        switch mode {
        case .recent(let video):
            return video.title
        case .subscribed(let video):
            return video.title
        case .downloaded(let video):
            return video.title
        }
    }


    //#################################################################################
    // MARK: - Private Views
    //#################################################################################

    private var coverImageWithBadge: some View {
        ZStack(alignment: .bottomLeading) {
            KFImage(coverURL)
                .resizable()
                .placeholder {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.2))
                        .overlay {
                            Image(systemName: "photo")
                                .foregroundStyle(.secondary)
                        }
                }
                .aspectRatio(contentMode: .fill)
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

            episodeBadge
        }
    }

    @ViewBuilder
    private var episodeBadge: some View {
        switch mode {
        case .downloaded(let video):
            badgeText("\(video.totalCount) ep")
        case .recent, .subscribed:
            EmptyView()
        }
    }

    private func badgeText(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.white)
            .padding(.horizontal, .spacingXS)
            .padding(.vertical, 2)
            .background(.black.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusXS))
            .padding(.spacingXXS)
    }

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: .spacingXXS) {
            switch mode {
            case .recent(let video):
                recentInfoContent(video: video)
            case .subscribed:
                subscribedInfoContent
            case .downloaded(let video):
                downloadedInfoContent(video: video)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.trailing, .spacingS)
    }

    @ViewBuilder
    private func recentInfoContent(video: RecentVideo) -> some View {
        Text(video.title)
            .font(.body)
            .fontWeight(.medium)
            .lineLimit(2)

        if let sourceName, !sourceName.isEmpty {
            Text(sourceName)
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        if let episodeNumber = video.lastEpisodeNumber {
            Text("Episode \(episodeNumber)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var subscribedInfoContent: some View {
        Text(title)
            .font(.body)
            .fontWeight(.medium)
            .lineLimit(2)

        if let sourceName, !sourceName.isEmpty {
            Text(sourceName)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func downloadedInfoContent(video: DownloadedVideo) -> some View {
        Text(video.title)
            .font(.body)
            .fontWeight(.medium)
            .lineLimit(2)

        if let sourceName, !sourceName.isEmpty {
            Text(sourceName)
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        Text(downloadStatusText(for: video))
            .font(.caption)
            .foregroundStyle(.secondary)
            .textCase(.uppercase)

        if video.inProgressCount > 0 {
            HStack(spacing: .spacingXXS) {
                ProgressView(value: video.averageProgress)
                    .frame(width: Constants.stateViewHeight)

                Text("\(Int(video.averageProgress * 100))%")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }


    //#################################################################################
    // MARK: - Private Methods
    //#################################################################################

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func downloadStatusText(for video: DownloadedVideo) -> String {
        if video.inProgressCount > 0 {
            return "\(video.inProgressCount) in progress"
        } else {
            return "\(video.completedCount) downloaded"
        }
    }
}
