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

    /// The display mode for the row.
    enum Mode {
        /// General list display with subtitle and synopsis.
        case general
        /// Schedule display with air time label on top.
        case schedule
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

    private let item: RecommendingItem
    private let mode: Mode


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new `AnimeListRow`.
    /// - Parameters:
    ///   - item: The item to show.
    ///   - mode: The display mode. Defaults to `.general`.
    init(item: RecommendingItem, mode: Mode = .general) {
        self.item = item
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
    // MARK: - Private Views
    //#################################################################################

    private var coverImageWithBadge: some View {
        ZStack(alignment: .bottomLeading) {
            KFImage(item.coverURL)
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
        if let caption = item.caption {
            badgeText(caption)
        } else if let totalEpisodes = item.totalEpisodes {
            badgeText("\(totalEpisodes) ep")
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
            case .general:
                generalInfoContent
            case .schedule:
                scheduleInfoContent
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, .spacingS)
        .padding(.trailing, .spacingS)
    }

    @ViewBuilder
    private var generalInfoContent: some View {
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
    private var scheduleInfoContent: some View {
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


    //#################################################################################
    // MARK: - Private Methods
    //#################################################################################

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
