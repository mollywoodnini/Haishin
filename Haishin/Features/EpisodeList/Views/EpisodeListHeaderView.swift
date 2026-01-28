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

/// Header view displaying anime cover, title, and episode count.
struct EpisodeListHeaderView: View {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    private let title: String
    private let sourceName: String?
    private let coverURL: URL?
    private let subtitle: String?
    private let episodeCount: Int


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new episode list header view.
    /// - Parameter title: The anime title.
    /// - Parameter sourceName: Optional source name to display below the title.
    /// - Parameter coverURL: The cover image URL.
    /// - Parameter subtitle: Optional subtitle (e.g., genres).
    /// - Parameter episodeCount: The number of episodes.
    init(title: String,
         sourceName: String?,
         coverURL: URL?,
         subtitle: String?,
         episodeCount: Int) {
        self.title = title
        self.sourceName = sourceName
        self.coverURL = coverURL
        self.subtitle = subtitle
        self.episodeCount = episodeCount
    }

    /// Creates a new episode list header view from an Anime object.
    /// - Parameter anime: The anime to display.
    /// - Parameter sourceName: Optional source name to display below the title.
    init(anime: Anime, sourceName: String? = nil) {
        self.title = anime.title
        self.sourceName = sourceName
        self.coverURL = anime.coverURL
        self.subtitle = anime.genres.isEmpty ? nil : anime.genres.joined(separator: ", ")
        self.episodeCount = anime.episodes.count
    }


    //#################################################################################
    // MARK: - Body
    //#################################################################################

    var body: some View {
        HStack(alignment: .top, spacing: .spacingM) {
            KFImage(coverURL)
                .resizable()
                .placeholder {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 80, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusS))

            VStack(alignment: .leading, spacing: .spacingXS) {
                Text(title)
                    .font(.headline)
                    .lineLimit(2)

                if let sourceName, !sourceName.isEmpty {
                    Text(sourceName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Text("\(episodeCount) Episode\(episodeCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }
}
