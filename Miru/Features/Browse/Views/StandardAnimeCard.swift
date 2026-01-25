//
//  StandardAnimeCard.swift
//  Miru
//
//  Created by Miru on 24.01.26.
//

import SwiftUI
import Kingfisher


//#################################################################################
// MARK: - StandardAnimeCard
//#################################################################################

/// A standard anime card for horizontal sections showing cover and title.
struct StandardAnimeCard: View {

    //#################################################################################
    // MARK: - Constants
    //#################################################################################

    private struct Constants {
        static let cardWidth: CGFloat = 140
        static let imageHeight: CGFloat = 200
        static let textHeight: CGFloat = 60
    }


    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    private let item: RecommendingItem


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new standard anime card.
    /// - Parameter item: The recommending item to display.
    init(item: RecommendingItem) {
        self.item = item
    }


    //#################################################################################
    // MARK: - Body
    //#################################################################################

    var body: some View {
        VStack(alignment: .leading, spacing: .spacingXXS) {
            // Image with fixed height at top
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
                    .frame(width: Constants.cardWidth, height: Constants.imageHeight)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusS))

                // Episode count badge if available
                if let totalEpisodes = item.totalEpisodes {
                    Text("\(totalEpisodes) ep")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, .spacingXS)
                        .padding(.vertical, 3)
                        .background(.black.opacity(0.7))
                        .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusXS))
                        .padding(.spacingXXS)
                }
            }

            // Text content with spacer to push to bottom
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .frame(width: Constants.cardWidth, alignment: .leading)

                if let subtitle = item.subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .frame(width: Constants.cardWidth, alignment: .leading)
                }

                Spacer(minLength: 0)
            }
            .frame(height: Constants.textHeight)
        }
        .frame(width: Constants.cardWidth)
    }
}
