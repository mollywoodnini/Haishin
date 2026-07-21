//
//  RatingsStatisticsSectionView.swift
//  Haishin
//
//  Created by Haishin on 24.01.26.
//

import SwiftUI


//#################################################################################
// MARK: - RatingsStatisticsSectionView
//#################################################################################

/// A section view displaying anime ratings and statistics.
struct RatingsStatisticsSectionView: View {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    private let formattedScore: String?
    private let popularityString: String?
    private let favoritesString: String?


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new ratings and statistics section view.
    /// - Parameters:
    ///   - formattedScore: The formatted score string (e.g., "8.5").
    ///   - popularityString: The formatted popularity count.
    ///   - favoritesString: The formatted favorites count.
    init(formattedScore: String?, popularityString: String?, favoritesString: String?) {
        self.formattedScore = formattedScore
        self.popularityString = popularityString
        self.favoritesString = favoritesString
    }


    //#################################################################################
    // MARK: - Body
    //#################################################################################

    var body: some View {
        VStack(alignment: .leading, spacing: .spacingXS) {
            SectionHeader(title: "Ratings & Statistics")

            HStack(spacing: .spacingL) {
                if let score = formattedScore {
                    VStack(spacing: .spacingXXS) {
                        Text(score)
                            .font(.system(size: 36, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)

                        Text("Average Score")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(minWidth: 80)
                }

                VStack(alignment: .leading, spacing: .spacingXS) {
                    if let popularity = popularityString {
                        HStack {
                            Image(systemName: "person.2.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(popularity) users")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let favorites = favoritesString {
                        HStack {
                            Image(systemName: "heart.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(favorites) favorites")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()
            }
            .padding(.spacingS)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusS))
            .padding(.horizontal, .spacingS)
        }
        .padding(.top, .spacingS)
    }
}
