//
//  AniListAnimeDetail.swift
//  Haishin
//
//  Created by Haishin on 24.01.26.
//

import Foundation


//#################################################################################
// MARK: - AniListAnimeDetail
//#################################################################################

/// Detailed anime information fetched from AniList.
struct AniListAnimeDetail: Identifiable, Sendable {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    /// The AniList ID.
    let id: Int

    /// The primary title (English preferred, falls back to Romaji).
    let title: String

    /// The Romaji title.
    let romajiTitle: String?

    /// The native (Japanese) title.
    let nativeTitle: String?

    /// The English title.
    let englishTitle: String?

    /// URL to the cover/poster image.
    let coverURL: URL?

    /// URL to the banner image.
    let bannerURL: URL?

    /// Synopsis/description of the anime.
    let synopsis: String?

    /// Genres associated with the anime.
    let genres: [String]

    /// Average score (0-100).
    let averageScore: Int?

    /// Mean score (0-100).
    let meanScore: Int?

    /// Popularity ranking.
    let popularity: Int?

    /// Number of favorites.
    let favourites: Int?

    /// Current airing status.
    let status: AniListStatus

    /// The format (TV, Movie, OVA, etc.).
    let format: AniListFormat?

    /// Total number of episodes.
    let episodes: Int?

    /// Episode duration in minutes.
    let duration: Int?

    /// The season this anime aired.
    let season: AniListSeason?

    /// The year this anime aired.
    let seasonYear: Int?

    /// Start date of the anime.
    let startDate: AniListDate?

    /// End date of the anime.
    let endDate: AniListDate?

    /// The source material (Manga, Light Novel, Original, etc.).
    let source: String?

    /// Country of origin.
    let countryOfOrigin: String?

    /// Studios that produced this anime.
    let studios: [AniListStudio]

    /// Main characters with voice actors.
    let characters: [AniListCharacter]

    /// Related anime (sequels, prequels, spin-offs, etc.).
    let relations: [AniListRelation]

    /// Recommendations for similar anime.
    let recommendations: [AniListRecommendation]

    /// External links (official site, streaming, etc.).
    let externalLinks: [AniListExternalLink]

    /// Trailer information.
    let trailer: AniListTrailer?

    /// Tags describing the anime content.
    let tags: [AniListTag]

    /// Next airing episode information.
    let nextAiringEpisode: AniListAiringEpisode?

    /// URL to the AniList page.
    let siteUrl: URL?

    /// Alternative titles for search matching (romaji, english, native, excluding the primary title).
    var alternativeSearchTitles: [String] {
        [romajiTitle, englishTitle, nativeTitle]
            .compactMap { $0 }
            .filter { $0 != title && !$0.isEmpty }
    }
}


//#################################################################################
// MARK: - AniListStatus
//#################################################################################

/// The airing status of an anime on AniList.
enum AniListStatus: String, Codable, Sendable {
    case releasing = "RELEASING"
    case finished = "FINISHED"
    case notYetReleased = "NOT_YET_RELEASED"
    case cancelled = "CANCELLED"
    case hiatus = "HIATUS"
    case unknown

    /// Human-readable display string.
    var displayString: String {
        switch self {
        case .releasing: return "Currently Airing"
        case .finished: return "Finished"
        case .notYetReleased: return "Not Yet Released"
        case .cancelled: return "Cancelled"
        case .hiatus: return "On Hiatus"
        case .unknown: return "Unknown"
        }
    }
}


//#################################################################################
// MARK: - AniListFormat
//#################################################################################

/// The format/type of an anime on AniList.
enum AniListFormat: String, Codable, Sendable {
    case tv = "TV"
    case tvShort = "TV_SHORT"
    case movie = "MOVIE"
    case special = "SPECIAL"
    case ova = "OVA"
    case ona = "ONA"
    case music = "MUSIC"
    case unknown

    /// Human-readable display string.
    var displayString: String {
        switch self {
        case .tv: return "TV"
        case .tvShort: return "TV Short"
        case .movie: return "Movie"
        case .special: return "Special"
        case .ova: return "OVA"
        case .ona: return "ONA"
        case .music: return "Music"
        case .unknown: return "Unknown"
        }
    }
}


//#################################################################################
// MARK: - AniListSeason
//#################################################################################

/// The season an anime aired.
enum AniListSeason: String, Codable, Sendable {
    case winter = "WINTER"
    case spring = "SPRING"
    case summer = "SUMMER"
    case fall = "FALL"

    /// Human-readable display string.
    var displayString: String {
        rawValue.capitalized
    }
}


//#################################################################################
// MARK: - AniListDate
//#################################################################################

/// A partial date from AniList (year, month, day may be nil).
struct AniListDate: Sendable {
    let year: Int?
    let month: Int?
    let day: Int?

    /// Formats the date as a string.
    var formattedString: String? {
        guard let year = year else { return nil }

        if let month = month, let day = day {
            return String(format: "%04d-%02d-%02d", year, month, day)
        } else if let month = month {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM yyyy"
            var components = DateComponents()
            components.year = year
            components.month = month
            if let date = Calendar.current.date(from: components) {
                return formatter.string(from: date)
            }
        }
        return "\(year)"
    }
}


//#################################################################################
// MARK: - AniListStudio
//#################################################################################

/// A studio that produced an anime.
struct AniListStudio: Identifiable, Sendable {
    let id: Int
    let name: String
    let isAnimationStudio: Bool
}


//#################################################################################
// MARK: - AniListCharacter
//#################################################################################

/// A character from an anime with voice actor info.
struct AniListCharacter: Identifiable, Sendable {
    let id: Int
    let name: String
    let imageURL: URL?
    let role: CharacterRole
    let voiceActorName: String?
    let voiceActorImageURL: URL?

    enum CharacterRole: String, Codable, Sendable {
        case main = "MAIN"
        case supporting = "SUPPORTING"
        case background = "BACKGROUND"

        var displayString: String {
            rawValue.capitalized
        }
    }
}


//#################################################################################
// MARK: - AniListRelation
//#################################################################################

/// A related anime (sequel, prequel, etc.).
struct AniListRelation: Identifiable, Sendable {
    let id: Int
    let title: String
    let coverURL: URL?
    let relationType: RelationType
    let format: AniListFormat?
    let status: AniListStatus

    enum RelationType: String, Codable, Sendable {
        case adaptation = "ADAPTATION"
        case prequel = "PREQUEL"
        case sequel = "SEQUEL"
        case parent = "PARENT"
        case sideStory = "SIDE_STORY"
        case character = "CHARACTER"
        case summary = "SUMMARY"
        case alternative = "ALTERNATIVE"
        case spinOff = "SPIN_OFF"
        case other = "OTHER"
        case source = "SOURCE"
        case compilation = "COMPILATION"
        case contains = "CONTAINS"

        var displayString: String {
            switch self {
            case .adaptation: return "Adaptation"
            case .prequel: return "Prequel"
            case .sequel: return "Sequel"
            case .parent: return "Parent"
            case .sideStory: return "Side Story"
            case .character: return "Character"
            case .summary: return "Summary"
            case .alternative: return "Alternative"
            case .spinOff: return "Spin Off"
            case .other: return "Other"
            case .source: return "Source"
            case .compilation: return "Compilation"
            case .contains: return "Contains"
            }
        }
    }
}


//#################################################################################
// MARK: - AniListRecommendation
//#################################################################################

/// A recommended similar anime.
struct AniListRecommendation: Identifiable, Sendable {
    let id: Int
    let title: String
    let coverURL: URL?
    let rating: Int
}


//#################################################################################
// MARK: - AniListExternalLink
//#################################################################################

/// An external link to streaming sites, official pages, etc.
struct AniListExternalLink: Identifiable, Sendable {
    let id: Int
    let url: URL
    let site: String
    let type: LinkType?
    let icon: URL?
    let color: String?

    enum LinkType: String, Codable, Sendable {
        case streaming = "STREAMING"
        case social = "SOCIAL"
        case info = "INFO"
    }
}


//#################################################################################
// MARK: - AniListTrailer
//#################################################################################

/// Trailer information for an anime.
struct AniListTrailer: Sendable {
    let id: String
    let site: String
    let thumbnail: URL?

    /// The full URL to the trailer video.
    var videoURL: URL? {
        switch site.lowercased() {
        case "youtube":
            return URL(string: "https://www.youtube.com/watch?v=\(id)")
        case "dailymotion":
            return URL(string: "https://www.dailymotion.com/video/\(id)")
        default:
            return nil
        }
    }
}


//#################################################################################
// MARK: - AniListTag
//#################################################################################

/// A tag describing anime content.
struct AniListTag: Identifiable, Sendable {
    let id: Int
    let name: String
    let rank: Int
    let isMediaSpoiler: Bool
}


//#################################################################################
// MARK: - AniListAiringEpisode
//#################################################################################

/// Information about the next airing episode.
struct AniListAiringEpisode: Sendable {
    let episode: Int
    let airingAt: Date
    let timeUntilAiring: TimeInterval

    /// Formatted countdown string.
    var countdownString: String {
        let days = Int(timeUntilAiring) / 86400
        let hours = (Int(timeUntilAiring) % 86400) / 3600
        let minutes = (Int(timeUntilAiring) % 3600) / 60

        if days > 0 {
            return "\(days)d \(hours)h"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}
