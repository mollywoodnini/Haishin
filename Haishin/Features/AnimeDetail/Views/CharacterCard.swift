//
//  CharacterCard.swift
//  Haishin
//
//  Created by Haishin on 24.01.26.
//

import Kingfisher
import SwiftUI


//#################################################################################
// MARK: - CharacterCard
//#################################################################################

/// A card displaying character information with image and voice actor.
struct CharacterCard: View {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    private let character: AniListCharacter


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new character card.
    /// - Parameter character: The character to display.
    init(character: AniListCharacter) {
        self.character = character
    }


    //#################################################################################
    // MARK: - Body
    //#################################################################################

    var body: some View {
        VStack(spacing: .spacingXXS) {
            KFImage(character.imageURL)
                .resizable()
                .placeholder {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.2))
                        .overlay {
                            Image(systemName: "person.fill")
                                .foregroundStyle(.secondary)
                        }
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 80, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusXS))

            VStack(spacing: 2) {
                Text(character.name)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)

                if let voiceActor = character.voiceActorName {
                    Text(voiceActor)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(width: 80)
        }
    }
}
