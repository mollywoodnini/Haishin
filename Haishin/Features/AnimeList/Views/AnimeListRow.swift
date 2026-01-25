//
//  AnimeListRow.swift
//  Haishin
//
//  Created by Tan Nghia La on 25.01.26.
//

import Kingfisher
import SwiftUI


//#################################################################################
// MARK: - AnimeListRow
//#################################################################################

/// A row showing an anime in the list view.
struct AnimeListRow: View {

    //#################################################################################
    // MARK: - Types
    //#################################################################################

    /// The display mode for the row with associated model data.
    enum Mode {
        /// General list display with subtitle and synopsis.
        case general(RecommendingItem)
        /// Schedule display with air time label on top.
        case schedule(RecommendingItem)
        /// Recent anime display with last watched episode.
        case recent(RecentAnime)
        /// Subscribed anime display.
        case subscribed(SubscribedAnime)
        /// Downloaded anime display with episode count and progress.
        case downloaded(DownloadedAnime)
    }


    //#################################################################################
    // MARK: - Constants
    //#################################################################################

    private struct Constants {
        static let imageWidth: CGFloat = 85
        static let rowHeight: CGFloat = 120
    }


    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    private let mode: Mode


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new `AnimeListRow`.
    /// - Parameter mode: The display mode containing the model data.
    init(mode: Mode) {
        self.mode = mode
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
        case .general(let item), .schedule(let item):
            return item.coverURL
        case .recent(let anime):
            return anime.coverURL
        case .subscribed(let anime):
            return anime.coverURL
        case .downloaded(let anime):
            return anime.coverURL
        }
    }

    private var title: String {
        switch mode {
        case .general(let item), .schedule(let item):
            return item.title
        case .recent(let anime):
            return anime.title
        case .subscribed(let anime):
            return anime.title
        case .downloaded(let anime):
            return anime.title
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
                    UnevenRoundedRectangle(topLeadingRadius: .cornerRadiusM,
                                           bottomLeadingRadius: .cornerRadiusM,
                                           bottomTrailingRadius: 0,
                                           topTrailingRadius: 0)
                )

            episodeBadge
        }
    }

    @ViewBuilder
    private var episodeBadge: some View {
        switch mode {
        case .general(let item), .schedule(let item):
            if let caption = item.caption {
                badgeText(caption)
            } else if let totalEpisodes = item.totalEpisodes {
                badgeText("\(totalEpisodes) ep")
            }
        case .downloaded(let anime):
            badgeText("\(anime.totalCount) ep")
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
            case .general(let item):
                generalInfoContent(item: item)
            case .schedule(let item):
                scheduleInfoContent(item: item)
            case .recent(let anime):
                recentInfoContent(anime: anime)
            case .subscribed:
                subscribedInfoContent
            case .downloaded(let anime):
                downloadedInfoContent(anime: anime)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.trailing, .spacingS)
    }

    @ViewBuilder
    private func generalInfoContent(item: RecommendingItem) -> some View {
        Text(item.title)
            .font(.body)
            .fontWeight(.medium)
            .lineLimit(2)

        if let subtitle = item.subtitle {
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }

        if let synopsis = item.synopsis {
            Text(synopsis)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }

    @ViewBuilder
    private func scheduleInfoContent(item: RecommendingItem) -> some View {
        if let airDate = item.airDate {
            Text(formatTime(airDate))
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.highlight)
        }

        Text(item.title)
            .font(.body)
            .fontWeight(.medium)
            .lineLimit(2)

        if let synopsis = item.synopsis {
            Text(synopsis)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }

    @ViewBuilder
    private func recentInfoContent(anime: RecentAnime) -> some View {
        Text(anime.title)
            .font(.body)
            .fontWeight(.medium)
            .lineLimit(2)

        if let episodeNumber = anime.lastEpisodeNumber {
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
    }

    @ViewBuilder
    private func downloadedInfoContent(anime: DownloadedAnime) -> some View {
        Text(anime.title)
            .font(.body)
            .fontWeight(.medium)
            .lineLimit(2)

        Text(downloadStatusText(for: anime))
            .font(.caption)
            .foregroundStyle(.secondary)
            .textCase(.uppercase)

        if anime.inProgressCount > 0 {
            HStack(spacing: .spacingXXS) {
                ProgressView(value: anime.averageProgress)
                    .frame(width: 60)

                Text("\(Int(anime.averageProgress * 100))%")
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

    private func downloadStatusText(for anime: DownloadedAnime) -> String {
        if anime.inProgressCount > 0 {
            return "\(anime.inProgressCount) in progress"
        } else {
            return "\(anime.completedCount) downloaded"
        }
    }
}
