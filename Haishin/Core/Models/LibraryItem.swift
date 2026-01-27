//
//  LibraryItem.swift
//  Haishin
//
//  Created by Haishin on 24.01.26.
//

import Foundation

/// An anime saved to the user's library.
struct LibraryItem: Identifiable, Hashable, Codable {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    /// Unique identifier.
    let id: UUID

    /// The anime preview data.
    let anime: AnimePreview

    /// Category/list the anime belongs to.
    var category: LibraryCategory

    /// Last episode number watched.
    var lastWatchedEpisode: String?

    /// Progress through the last watched episode (0.0 to 1.0).
    var lastWatchedProgress: Double?

    /// Date when the anime was added to library.
    let addedAt: Date

    /// Date when the anime was last watched.
    var lastWatchedAt: Date?


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new library item.
    /// - Parameters:
    ///   - anime: The anime to add to the library.
    ///   - category: The library category.
    init(anime: AnimePreview, category: LibraryCategory = .watching) {
        self.id = UUID()
        self.anime = anime
        self.category = category
        self.lastWatchedEpisode = nil
        self.lastWatchedProgress = nil
        self.addedAt = Date()
        self.lastWatchedAt = nil
    }
}


//#################################################################################
// MARK: - LibraryCategory
//#################################################################################

/// Categories for organizing anime in the library.
enum LibraryCategory: String, Codable, CaseIterable, Identifiable {
    case watching
    case planToWatch
    case completed
    case onHold
    case dropped

    /// Unique identifier for Identifiable conformance.
    var id: String { rawValue }

    /// Display name for the category.
    var displayName: String {
        switch self {
        case .watching: return "Watching"
        case .planToWatch: return "Plan to Watch"
        case .completed: return "Completed"
        case .onHold: return "On Hold"
        case .dropped: return "Dropped"
        }
    }

    /// SF Symbol icon for the category.
    var iconName: String {
        switch self {
        case .watching: return "play.circle"
        case .planToWatch: return "bookmark"
        case .completed: return "checkmark.circle"
        case .onHold: return "pause.circle"
        case .dropped: return "xmark.circle"
        }
    }
}
