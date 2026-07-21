//
//  GenresSectionView.swift
//  Haishin
//
//  Created by Haishin on 24.01.26.
//

import SwiftUI


//#################################################################################
// MARK: - GenresSectionView
//#################################################################################

/// A section view displaying horizontal genre pills.
struct GenresSectionView: View {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    private let genres: [String]


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new genres section view.
    /// - Parameter genres: The list of genres to display.
    init(genres: [String]) {
        self.genres = genres
    }


    //#################################################################################
    // MARK: - Body
    //#################################################################################

    var body: some View {
        VStack(alignment: .leading, spacing: .spacingXS) {
            SectionHeader(title: "Genres")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: .spacingXS) {
                    ForEach(genres, id: \.self) { genre in
                        Text(genre)
                            .font(.subheadline)
                            .padding(.horizontal, .spacingS)
                            .padding(.vertical, .spacingXS)
                            .background(Color.highlight.opacity(0.15))
                            .foregroundStyle(.highlight)
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, .spacingS)
            }
        }
        .padding(.top, .spacingS)
    }
}
