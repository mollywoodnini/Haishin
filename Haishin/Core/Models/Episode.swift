//
//  Episode.swift
//  Miru
//
//  Created by Miru on 24.01.26.
//

import Foundation

/// Represents a single episode of an anime.
struct Episode: Identifiable, Hashable, Codable {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    /// Unique identifier for the episode within the anime.
    let id: String

    /// Episode number (e.g., "1", "12.5", "OVA 1").
    let number: String

    /// Episode title, if available.
    let title: String?

    /// URL to the episode's thumbnail image.
    let thumbnailURL: URL?

    /// URL path to fetch video sources for this episode.
    let url: String

    /// Duration in seconds, if known.
    let duration: TimeInterval?
}


//#################################################################################
// MARK: - VideoSource
//#################################################################################

/// A video source/server for an episode.
struct VideoSource: Identifiable, Hashable, Codable {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    /// Unique identifier for this source.
    let id: String

    /// Display name of the server (e.g., "VidStreaming", "Mp4Upload").
    let serverName: String

    /// Quality label (e.g., "1080p", "720p", "auto").
    let quality: String?

    /// Direct URL to the video stream.
    let url: URL

    /// HTTP headers required for playback (e.g., Referer).
    let headers: [String: String]?

    /// Whether this source requires extraction via a parser.
    let requiresExtraction: Bool
}


//#################################################################################
// MARK: - PlaybackInfo
//#################################################################################

/// Complete playback information for an episode.
struct PlaybackInfo: Identifiable, Hashable {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    /// Unique identifier.
    var id: String { episodeId }

    /// The episode this playback info belongs to.
    let episodeId: String

    /// Available video sources/servers.
    let sources: [VideoSource]

    /// Subtitle tracks, if available.
    let subtitles: [Subtitle]
}


//#################################################################################
// MARK: - Subtitle
//#################################################################################

/// A subtitle track for video playback.
struct Subtitle: Identifiable, Hashable, Codable {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    /// Unique identifier.
    let id: String

    /// Language code (e.g., "en", "ja").
    let language: String

    /// Display label (e.g., "English", "Japanese").
    let label: String

    /// URL to the subtitle file.
    let url: URL
}
