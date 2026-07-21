//
//  UpcomingEpisodeCard.swift
//  Haishin
//
//  Created by Haishin on 24.01.26.
//

import SwiftUI


//#################################################################################
// MARK: - UpcomingEpisodeCard
//#################################################################################

/// A card showing upcoming episode information with countdown timer.
struct UpcomingEpisodeCard: View {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    private let episode: AniListAiringEpisode


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new upcoming episode card.
    /// - Parameter episode: The airing episode to display.
    init(episode: AniListAiringEpisode) {
        self.episode = episode
    }


    //#################################################################################
    // MARK: - Body
    //#################################################################################

    var body: some View {
        VStack(alignment: .leading, spacing: .spacingXS) {
            Text("Episode \(episode.episode) airing in")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(formattedCountdown)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)

            Text(formattedAiringDate)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(width: 270, height: 95, alignment: .leading)
        .padding(.spacingS)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusM))
    }


    //#################################################################################
    // MARK: - Formatted Properties
    //#################################################################################

    private var formattedCountdown: String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        formatter.maximumUnitCount = 2
        formatter.allowedUnits = [.day, .hour, .minute]
        return formatter.string(from: episode.timeUntilAiring) ?? episode.countdownString
    }

    private var formattedAiringDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        return formatter.string(from: episode.airingAt)
    }
}
