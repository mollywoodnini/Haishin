//
//  SourceModels.swift
//  Miru
//
//  Created by Miru on 24.01.26.
//

import Foundation


//#################################################################################
// MARK: - JSAnimePreview
//#################################################################################

/// A preview of an anime from a JavaScript source (used in search results and featured lists)
struct JSAnimePreview: Codable, Identifiable, Sendable, Hashable {
    
    /// Unique identifier for this anime
    let id: String
    
    /// The anime title (original or preferred language)
    let title: String
    
    /// English title (if available)
    let englishTitle: String?
    
    /// Cover/poster image URL
    let coverUrl: String
    
    /// Full URL to the anime's page on the source website
    let url: String
    
    /// Source that provided this anime
    let sourceId: String?
}


//#################################################################################
// MARK: - JSSearchResult
//#################################################################################

/// Result from a search operation on a JavaScript source
struct JSSearchResult: Codable, Sendable {
    
    /// The anime found in this search
    let results: [JSAnimePreview]
    
    /// Whether there are more pages available
    let hasNextPage: Bool
}


//#################################################################################
// MARK: - JSAnimeDetails
//#################################################################################

/// Detailed information about an anime from a JavaScript source
struct JSAnimeDetails: Codable, Sendable {

    /// Unique identifier for this anime
    let id: String

    /// The anime title (original or preferred language)
    let title: String

    /// English title (if available)
    let englishTitle: String?

    /// Synopsis/description
    let synopsis: String

    /// Cover/poster image URL
    let coverUrl: String

    /// Rating (e.g., 8.5 out of 10)
    let rating: Double?

    /// Release date (ISO 8601 format)
    let releaseDate: String?

    /// Current status
    let status: AnimeStatus

    /// Genres
    let genres: [String]

    /// Available servers/sources for streaming
    /// Key: server ID, Value: server display name
    let servers: [String: String]

    /// Episodes organized by server
    /// Key: server ID, Value: array of episodes
    let episodes: [String: [SourceEpisode]]

    /// Episode ranges organized by server (for anime with many episodes)
    /// Key: server ID, Value: array of episode ranges
    /// Optional - only present when source provides range information
    let episodeRanges: [String: [SourceEpisodeRange]]?
}


//#################################################################################
// MARK: - AnimeStatus
//#################################################################################

/// The current airing status of an anime
enum AnimeStatus: String, Codable, Sendable {
    case ongoing
    case completed
    case upcoming
    case unknown
}


//#################################################################################
// MARK: - SourceEpisodeRange
//#################################################################################

/// A range of episodes (e.g., "1 - 50") from a JavaScript source
struct SourceEpisodeRange: Codable, Identifiable, Sendable, Hashable {

    /// Unique identifier for this range (typically the range-id from HTML)
    let id: String

    /// Display title for the range (e.g., "1 - 50", "51 - 100")
    let title: String

    /// Episodes within this range
    let episodes: [SourceEpisode]
}


//#################################################################################
// MARK: - SourceEpisode
//#################################################################################

/// An anime episode from a JavaScript source
struct SourceEpisode: Codable, Identifiable, Sendable, Hashable {

    /// Unique identifier for this episode
    let id: String

    /// Episode number
    let number: Int

    /// Episode title
    let title: String

    /// Full URL to the episode page
    let url: String
}


//#################################################################################
// MARK: - JSEpisodeStream
//#################################################################################

/// Streaming information for an episode from a JavaScript source
struct JSEpisodeStream: Codable, Sendable {
    
    /// Available video streams
    let streams: [Stream]
    
    /// Available subtitles (optional)
    let subtitles: [SourceSubtitle]?
}


//#################################################################################
// MARK: - Stream
//#################################################################################

/// A video stream
struct Stream: Codable, Sendable, Hashable {
    
    /// Quality identifier (e.g., "1080p", "720p", "default")
    let quality: String
    
    /// Direct URL to the video stream
    let url: String
    
    /// Stream type
    let type: StreamType
    
    /// HTTP headers required for playback (e.g., Referer, User-Agent)
    let headers: [String: String]?
}


//#################################################################################
// MARK: - StreamType
//#################################################################################

/// Type of video stream
enum StreamType: String, Codable, Sendable {
    case m3u8  // HLS stream
    case mp4   // Direct MP4
    case dash  // DASH stream
}


//#################################################################################
// MARK: - SourceSubtitle
//#################################################################################

/// A subtitle track from a JavaScript source
struct SourceSubtitle: Codable, Sendable, Hashable {
    
    /// Language code (e.g., "en", "ja", "it")
    let language: String
    
    /// Display label (e.g., "English", "Italian")
    let label: String?
    
    /// URL to the subtitle file (typically .vtt or .srt)
    let url: String
}


