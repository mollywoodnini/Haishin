//
//  VideoProtocol.swift
//  Haishin
//
//  Created by Tan Nghia La on 24.01.28.
//

import Foundation


//#################################################################################
// MARK: - VideoProtocol
//#################################################################################

/// Protocol defining the common properties shared by all video representations.
/// Types conforming to this protocol can be used interchangeably in views
/// that only need basic video information for display.
protocol VideoProtocol: Identifiable, Hashable {

    /// The video ID.
    var id: String { get }

    /// The video title.
    var title: String { get }

    /// URL to the cover image.
    var coverURL: URL? { get }

    /// The source ID used to fetch this video.
    var sourceId: String { get }

    /// The direct URL to the video details page (for direct navigation without search).
    var detailsURL: String? { get }

    /// Alternative titles for improved search matching (e.g., romaji, english, native).
    var alternativeTitles: [String] { get }
}

extension VideoProtocol {
    var alternativeTitles: [String] { [] }
}
