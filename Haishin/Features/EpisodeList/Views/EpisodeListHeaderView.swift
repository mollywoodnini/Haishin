//
//  EpisodeListHeaderView.swift
//  Haishin
//
//  Created by Haishin on 25.01.26.
//

import Kingfisher
import SwiftUI


//#################################################################################
// MARK: - EpisodeListHeaderView
//#################################################################################

/// Header view displaying anime cover, title, genres, and episode count.
struct EpisodeListHeaderView: View {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    private let anime: Anime


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new episode list header view.
    /// - Parameter anime: The anime to display.
    init(anime: Anime) {
        self.anime = anime
    }


    //#################################################################################
    // MARK: - Body
    //#################################################################################

    var body: some View {
        HStack(alignment: .top, spacing: .spacingM) {
            KFImage(anime.coverURL)
                .resizable()
                .placeholder {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 80, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusS))

            VStack(alignment: .leading, spacing: .spacingXS) {
                Text(anime.title)
                    .font(.headline)
                    .lineLimit(2)

                if !anime.genres.isEmpty {
                    Text(anime.genres.joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Text("\(anime.episodes.count) Episode\(anime.episodes.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }
}
