//
//  RecommendationsSectionView.swift
//  Miru
//
//  Created by Miru on 24.01.26.
//

import SwiftUI


//#################################################################################
// MARK: - RecommendationsSectionView
//#################################################################################

/// A section view displaying recommended anime with navigation links.
struct RecommendationsSectionView<Destination: View>: View {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    private let recommendations: [AniListRecommendation]
    private let destinationBuilder: (AniListRecommendation) -> Destination


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new recommendations section view.
    /// - Parameters:
    ///   - recommendations: The list of recommended anime to display.
    ///   - destinationBuilder: A closure that builds the destination view for each recommendation.
    init(recommendations: [AniListRecommendation],
         @ViewBuilder destinationBuilder: @escaping (AniListRecommendation) -> Destination) {
        self.recommendations = recommendations
        self.destinationBuilder = destinationBuilder
    }


    //#################################################################################
    // MARK: - Body
    //#################################################################################

    var body: some View {
        VStack(alignment: .leading, spacing: .spacingXS) {
            SectionHeader(title: "You Might Also Like")

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: .spacingS) {
                    ForEach(recommendations) { rec in
                        NavigationLink {
                            destinationBuilder(rec)
                        } label: {
                            RecommendationCard(recommendation: rec)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, .spacingS)
            }
        }
        .padding(.top, .spacingS)
    }
}
