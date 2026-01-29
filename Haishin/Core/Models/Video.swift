//
//  Video.swift
//  Haishin
//
//  Created by Tan Nghia La on 24.01.26.
//

import Foundation

/// A lightweight reference to a video, used for lists and navigation.
struct VideoPreview: VideoProtocol, Codable {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    /// Unique identifier for the video within a source.
    let id: String

    /// Display title of the video.
    let title: String

    /// URL to the video's cover/poster image.
    let coverURL: URL?

    /// The source this video belongs to.
    let sourceId: String

    /// URL path to fetch full video details.
    let detailsURL: String
}


//#################################################################################
// MARK: - Video
//#################################################################################

/// Full video details including episodes and metadata.
struct Video: VideoProtocol, Codable {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    /// Unique identifier for the video within a source.
    let id: String

    /// Display title of the video.
    let title: String

    /// Alternative titles (e.g., Japanese, English, synonyms).
    let alternativeTitles: [String]

    /// URL to the video's cover/poster image.
    let coverURL: URL?

    /// URL to the video's banner image.
    let bannerURL: URL?

    /// Synopsis or description of the video.
    let synopsis: String?

    /// Genres associated with the video.
    let genres: [String]

    /// Current airing status.
    let status: AiringStatus

    /// Release year.
    let year: Int?

    /// Content rating (e.g., PG-13, R).
    let rating: String?

    /// The source this video belongs to.
    let sourceId: String

    /// URL path used to fetch this video's details.
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

/// A range of episodes for better organization of long-running series.
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

/// The airing status of a video.
enum AiringStatus: String, Codable, CaseIterable {
    case ongoing
    case completed
    case upcoming
    case unknown
}
