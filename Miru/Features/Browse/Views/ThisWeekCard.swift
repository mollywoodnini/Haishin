//
//  ThisWeekCard.swift
//  Miru
//
//  Created by Miru on 24.01.26.
//

import SwiftUI


//#################################################################################
// MARK: - ThisWeekCard
//#################################################################################

/// A card for the "This Week" section showing air date and episode info.
struct ThisWeekCard: View {

    //#################################################################################
    // MARK: - Constants
    //#################################################################################

    private struct Constants {
        static let cardWidth: CGFloat = 300
        static let cardHeight: CGFloat = 200
        static let imageWidth: CGFloat = 120
    }


    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    private let item: RecommendingItem


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new this week card.
    /// - Parameter item: The recommending item to display.
    init(item: RecommendingItem) {
        self.item = item
    }


    //#################################################################################
    // MARK: - Body
    //#################################################################################

    var body: some View {
        HStack(spacing: .spacingS) {
            // Cover image with episode badge overlay
            ZStack(alignment: .bottomLeading) {
                AsyncImage(url: item.coverURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.2))
                        .overlay {
                            Image(systemName: "photo")
                                .foregroundStyle(.secondary)
                        }
                }
                .frame(width: Constants.imageWidth, height: Constants.cardHeight)
                .clipped()
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: .cornerRadiusM,
                        bottomLeadingRadius: .cornerRadiusM,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: 0
                    )
                )

                // Episode badge
                if let caption = item.caption {
                    Text(caption)
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

            // Info
            VStack(alignment: .leading, spacing: .spacingXXS) {
                if let date = item.subtitle {
                    Text(date)
                        .font(.subheadline)
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
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, .spacingXS)
            .padding(.trailing, .spacingXS)
        }
        .frame(width: Constants.cardWidth, height: Constants.cardHeight)
        .background(Color.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusM))
    }
}
