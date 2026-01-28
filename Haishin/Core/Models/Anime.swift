//
//  Anime.swift
//  Haishin
//
//  Created by Tan Nghia La on 24.01.26.
//

import Foundation

/// A lightweight reference to an anime, used for lists and navigation.
struct AnimePreview: AnimeProtocol, Codable {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    /// Unique identifier for the anime within a source.
    let id: String

    /// Display title of the anime.
    let title: String

    /// URL to the anime's cover/poster image.
    let coverURL: URL?

    /// The source this anime belongs to.
    let sourceId: String

    /// URL path to fetch full anime details.
    let detailsURL: String
}


//#################################################################################
// MARK: - Anime
//#################################################################################

/// Full anime details including episodes and metadata.
struct Anime: AnimeProtocol, Codable {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    /// Unique identifier for the anime within a source.
    let id: String

    /// Display title of the anime.
    let title: String

    /// Alternative titles (e.g., Japanese, English, synonyms).
    let alternativeTitles: [String]

    /// URL to the anime's cover/poster image.
    let coverURL: URL?

    /// URL to the anime's banner image.
    let bannerURL: URL?

    /// Synopsis or description of the anime.
    let synopsis: String?

    /// Genres associated with the anime.
    let genres: [String]

    /// Current airing status.
    let status: AiringStatus

    /// Release year.
    let year: Int?

    /// Content rating (e.g., PG-13, R).
    let rating: String?

    /// The source this anime belongs to.
    let sourceId: String

    /// URL path used to fetch this anime's details.
    let detailsURL: String

    /// Available episodes (flat list for backward compatibility).
    let episodes: [Episode]

    /// Episode ranges for better organization (e.g., "1-50", "51-100").
    /// If not provided, defaults to a single range containing all episodes.
    let episodeRanges: [EpisodeRange]
}


//#################################################################################
// MARK: - EpisodeRange
//#################################################################################

/// A range of episodes for better organization of long-running anime.
struct EpisodeRange: Identifiable, Hashable, Codable {

    /// Unique identifier for this range.
    let id: String

    /// Display title for the range (e.g., "1 - 50", "51 - 100").
    let title: String

    /// Episodes within this range.
    let episodes: [Episode]
}


//#################################################################################
// MARK: - AiringStatus
//#################################################################################

/// The airing status of an anime.
enum AiringStatus: String, Codable, CaseIterable {
    case ongoing
    case completed
    case upcoming
    case unknown
}
