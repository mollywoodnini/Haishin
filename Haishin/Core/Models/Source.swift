//
//  Source.swift
//  Miru
//
//  Created by Miru on 24.01.26.
//

import Foundation

/// Metadata about an external anime source.
struct SourceInfo: Identifiable, Hashable, Codable {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    /// Unique identifier for the source.
    let id: String

    /// Display name of the source.
    let name: String

    /// Source version (semver format).
    let version: String

    /// Language/locale of the source content.
    let language: String

    /// Base URL of the source website.
    let baseURL: URL

    /// URL to the source's icon/logo.
    let iconURL: URL?

    /// Whether this source provides NSFW content.
    let isNSFW: Bool

    /// Description of the source.
    let description: String?
}


//#################################################################################
// MARK: - SourceRepository
//#################################################################################

/// A repository containing multiple sources.
struct SourceRepository: Identifiable, Hashable, Codable {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    /// Unique identifier for the repository.
    var id: String { url.absoluteString }

    /// Display name of the repository.
    let name: String

    /// URL to the repository manifest.
    let url: URL

    /// Available sources in this repository.
    var sources: [SourceInfo]
}


//#################################################################################
// MARK: - InstalledSource
//#################################################################################

/// Represents an installed and active source.
struct InstalledSource: Identifiable, Hashable {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    /// Unique identifier (same as source info id).
    var id: String { info.id }

    /// Source metadata.
    let info: SourceInfo

    /// Path to the installed JavaScript file.
    let scriptPath: URL

    /// Whether the source is currently enabled.
    var isEnabled: Bool

    /// Date when the source was installed.
    let installedAt: Date
}
