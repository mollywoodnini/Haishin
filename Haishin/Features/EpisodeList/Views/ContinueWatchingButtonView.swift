//
//  ContinueWatchingButtonView.swift
//  Haishin
//
//  Created by Haishin on 25.01.26.
//

import SwiftUI


//#################################################################################
// MARK: - ContinueWatchingButtonView
//#################################################################################

/// A button that prompts the user to continue watching an episode.
struct ContinueWatchingButtonView: View {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    private let episode: Episode
    private let onTap: () -> Void


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new continue watching button.
    /// - Parameters:
    ///   - episode: The episode to continue watching.
    ///   - onTap: Action to perform when the button is tapped.
    init(episode: Episode, onTap: @escaping () -> Void) {
        self.episode = episode
        self.onTap = onTap
    }


    //#################################################################################
    // MARK: - Body
    //#################################################################################

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: .spacingM) {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.accentColor)

                VStack(alignment: .leading, spacing: .spacingXXS) {
                    Text("Continue Watching")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("Episode \(episode.number)")
                        .font(.headline)
                        .foregroundStyle(.primary)
                }

                Spacer()
            }
            .padding(.spacingM)
            .background(Color(.tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusS))
        }
        .buttonStyle(.plain)
    }
}
