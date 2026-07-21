//
//  RelationCard.swift
//  Haishin
//
//  Created by Haishin on 24.01.26.
//

import Kingfisher
import SwiftUI


//#################################################################################
// MARK: - RelationCard
//#################################################################################

/// A card displaying a related anime with cover and relation type badge.
struct RelationCard: View {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    private let relation: AniListRelation


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new relation card.
    /// - Parameter relation: The related anime to display.
    init(relation: AniListRelation) {
        self.relation = relation
    }


    //#################################################################################
    // MARK: - Body
    //#################################################################################

    var body: some View {
        VStack(alignment: .leading, spacing: .spacingXXS) {
            ZStack(alignment: .bottomLeading) {
                KFImage(relation.coverURL)
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
                    .frame(width: 100, height: 140)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusXS))

                // Relation type badge
                Text(relation.relationType.displayString)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, .spacingXXS)
                    .padding(.vertical, 2)
                    .background(.black.opacity(0.7))
                    .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusXS))
                    .padding(4)
            }

            Text(relation.title)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(2)
                .frame(width: 100, alignment: .leading)
        }
    }
}
