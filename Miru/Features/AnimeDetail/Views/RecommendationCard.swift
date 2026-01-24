//
//  RecommendationCard.swift
//  Miru
//
//  Created by Miru on 24.01.26.
//

import SwiftUI


//#################################################################################
// MARK: - RecommendationCard
//#################################################################################

/// A card displaying a recommended anime with cover and title.
struct RecommendationCard: View {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    private let recommendation: AniListRecommendation


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new recommendation card.
    /// - Parameter recommendation: The recommendation to display.
    init(recommendation: AniListRecommendation) {
        self.recommendation = recommendation
    }


    //#################################################################################
    // MARK: - Body
    //#################################################################################

    var body: some View {
        VStack(alignment: .leading, spacing: .spacingXXS) {
            AsyncImage(url: recommendation.coverURL) { image in
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
            .frame(width: 100, height: 140)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusXS))

            Text(recommendation.title)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(2)
                .frame(width: 100, alignment: .leading)
        }
    }
}
