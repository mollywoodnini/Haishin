//
//  AnimeProtocol.swift
//  Haishin
//
//  Created by Tan Nghia La on 24.01.28.
//

import Foundation


//#################################################################################
// MARK: - AnimeProtocol
//#################################################################################

/// Protocol defining the common properties shared by all anime representations.
/// Types conforming to this protocol can be used interchangeably in views
/// that only need basic anime information for display.
protocol AnimeProtocol: Identifiable, Hashable {

    /// The anime ID.
    var id: String { get }

    /// The anime title.
    var title: String { get }

    /// URL to the cover image.
    var coverURL: URL? { get }

    /// The source ID used to fetch this anime.
    var sourceId: String { get }
}
