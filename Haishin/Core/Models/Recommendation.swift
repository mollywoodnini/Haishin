//
//  Recommendation.swift
//  Haishin
//
//  Created by Tan Nghia La on 24.01.26.
//

import Foundation


//#################################################################################
// MARK: - RecommendationSection
//#################################################################################

/// A section of anime recommendations displayed in the Browse view.
struct RecommendationSection: Identifiable {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    /// Unique identifier for the section.
    let id: String

    /// Display title of the section (e.g., "This Week", "Trending").
    let title: String

    /// Optional subtitle (e.g., "Winter 2026").
    let subtitle: String?

    /// The visual style for displaying this section.
    let style: SectionStyle

    /// The type of anime list for pagination (nil for non-paginated sections).
    let listType: AnimeListType?

    /// The items in this section.
    var items: [RecommendingItem]

    /// The current loading state of this section.
    var loadingState: LoadingState


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new recommendation section.
    /// - Parameters:
    ///   - id: Unique identifier for the section.
    ///   - title: Display title of the section.
    ///   - subtitle: Optional subtitle.
    ///   - style: The visual style for displaying this section.
    ///   - listType: The type of anime list for pagination.
    ///   - items: The items in this section.
    ///   - loadingState: The current loading state.
    init(id: String,
         title: String,
         subtitle: String? = nil,
         style: SectionStyle,
         listType: AnimeListType? = nil,
         items: [RecommendingItem] = [],
         loadingState: LoadingState = .idle) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.style = style
        self.listType = listType
        self.items = items
        self.loadingState = loadingState
    }
}


//#################################################################################
// MARK: - SectionStyle
//#################################################################################

/// The visual style for a recommendation section.
enum SectionStyle: String, Codable {
    /// Calendar-style horizontal scrolling cards showing air dates.
    case thisWeek

    /// Standard horizontal scrolling list.
    case standard

    /// Wide cards for featured content.
    case wide
}


//#################################################################################
// MARK: - LoadingState
//#################################################################################

/// The loading state of a section or item.
enum LoadingState: Equatable {
    case idle
    case loading
    case loaded
    case failed(String)
}


//#################################################################################
// MARK: - RecommendingItem
//#################################################################################

/// An individual anime recommendation item.
struct RecommendingItem: Identifiable, Hashable {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    /// Unique identifier for the item.
    let id: String

    /// Display title of the anime.
    let title: String

    /// Subtitle text (e.g., air time or studio name).
    let subtitle: String?

    /// Caption text displayed as a badge (e.g., "Ep. 5").
    let caption: String?

    /// Whether the caption should be highlighted (e.g., new episode).
    let isCaptionHighlighted: Bool

    /// Synopsis or description.
    let synopsis: String?

    /// URL to the anime's cover/poster image.
    let coverURL: URL?

    /// The AniList ID for linking to full details.
    let anilistId: Int

    /// Air date if applicable (for "This Week" style).
    let airDate: Date?

    /// Episode number if applicable.
    let episodeNumber: Int?

    /// Total number of episodes if known.
    let totalEpisodes: Int?


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new recommending item.
    /// - Parameters:
    ///   - id: Unique identifier for the item.
    ///   - title: Display title of the anime.
    ///   - subtitle: Subtitle text.
    ///   - caption: Caption text displayed as a badge.
    ///   - isCaptionHighlighted: Whether the caption should be highlighted.
    ///   - synopsis: Synopsis or description.
    ///   - coverURL: URL to the anime's cover/poster image.
    ///   - anilistId: The AniList ID for linking to full details.
    ///   - airDate: Air date if applicable.
    ///   - episodeNumber: Episode number if applicable.
    ///   - totalEpisodes: Total number of episodes if known.
    init(id: String,
         title: String,
         subtitle: String? = nil,
         caption: String? = nil,
         isCaptionHighlighted: Bool = false,
         synopsis: String? = nil,
         coverURL: URL? = nil,
         anilistId: Int,
         airDate: Date? = nil,
         episodeNumber: Int? = nil,
         totalEpisodes: Int? = nil) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.caption = caption
        self.isCaptionHighlighted = isCaptionHighlighted
        self.synopsis = synopsis
        self.coverURL = coverURL
        self.anilistId = anilistId
        self.airDate = airDate
        self.episodeNumber = episodeNumber
        self.totalEpisodes = totalEpisodes
    }
}
