//
//  UpcomingSectionView.swift
//  Miru
//
//  Created by Miru on 24.01.26.
//

import SwiftUI

/// A section displaying upcoming episode information.
struct UpcomingSectionView: View {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    private let episode: AniListAiringEpisode


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new upcoming section view.
    /// - Parameter episode: The airing episode to display.
    init(episode: AniListAiringEpisode) {
        self.episode = episode
    }


    //#################################################################################
    // MARK: - Body
    //#################################################################################

    var body: some View {
        VStack(alignment: .leading, spacing: .spacingXS) {
            SectionHeader(title: "Upcoming")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: .spacingS) {
                    UpcomingEpisodeCard(episode: episode)
                }
                .padding(.horizontal, .spacingS)
            }
        }
        .padding(.top, .spacingS)
    }
}
