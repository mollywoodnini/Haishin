//
//  CharactersSectionView.swift
//  Miru
//
//  Created by Miru on 24.01.26.
//

import SwiftUI


//#################################################################################
// MARK: - CharactersSectionView
//#################################################################################

/// A section view displaying horizontal scrolling character cards.
struct CharactersSectionView: View {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    private let characters: [AniListCharacter]


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new characters section view.
    /// - Parameter characters: The list of characters to display.
    init(characters: [AniListCharacter]) {
        self.characters = characters
    }


    //#################################################################################
    // MARK: - Body
    //#################################################################################

    var body: some View {
        VStack(alignment: .leading, spacing: .spacingXS) {
            SectionHeader(title: "Characters")

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: .spacingS) {
                    ForEach(characters) { character in
                        CharacterCard(character: character)
                    }
                }
                .padding(.horizontal, .spacingS)
            }
        }
        .padding(.top, .spacingS)
    }
}
