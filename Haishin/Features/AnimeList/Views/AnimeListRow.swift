//
//  AnimeListRow.swift
//  Haishin
//
//  Created by Tan Nghia La on 25.01.26.
//

import Kingfisher
import SwiftUI

/// A row showing an anime in the list view.
struct AnimeListRow: View {

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
    
    
    /// Creates a new `AnimeListRow`.
    /// - Parameter item: The item to show.
    init(item: RecommendingItem) {
        self.item = item
    }


    //#################################################################################
    // MARK: - Body
    //#################################################################################

    var body: some View {
        HStack(spacing: .spacingS) {
            // Cover image with badge - flush to edges
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
                        .padding(.vertical, 2)
                        .background(.black.opacity(0.7))
                        .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusXS))
                        .padding(.spacingXXS)
                } else if let totalEpisodes = item.totalEpisodes {
                    Text("\(totalEpisodes) ep")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, .spacingXS)
                        .padding(.vertical, 2)
                        .background(.black.opacity(0.7))
                        .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusXS))
                        .padding(.spacingXXS)
                }
            }

            // Info
            VStack(alignment: .leading, spacing: .spacingXXS) {
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

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, .spacingS)
            .padding(.trailing, .spacingS)
        }
        .frame(height: Constants.rowHeight)
        .background(Color.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusM))
    }
}
