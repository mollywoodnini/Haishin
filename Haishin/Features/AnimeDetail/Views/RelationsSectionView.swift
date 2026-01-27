//
//  RelationsSectionView.swift
//  Haishin
//
//  Created by Haishin on 24.01.26.
//

import SwiftUI


//#################################################################################
// MARK: - RelationsSectionView
//#################################################################################

/// A section view displaying related anime with navigation links.
struct RelationsSectionView<Destination: View>: View {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    private let relations: [AniListRelation]
    private let destinationBuilder: (AniListRelation) -> Destination


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new relations section view.
    /// - Parameters:
    ///   - relations: The list of related anime to display.
    ///   - destinationBuilder: A closure that builds the destination view for each relation.
    init(relations: [AniListRelation],
         @ViewBuilder destinationBuilder: @escaping (AniListRelation) -> Destination) {
        self.relations = relations
        self.destinationBuilder = destinationBuilder
    }


    //#################################################################################
    // MARK: - Body
    //#################################################################################

    var body: some View {
        VStack(alignment: .leading, spacing: .spacingXS) {
            SectionHeader(title: "Related")

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: .spacingS) {
                    ForEach(relations) { relation in
                        NavigationLink {
                            destinationBuilder(relation)
                        } label: {
                            RelationCard(relation: relation)
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
