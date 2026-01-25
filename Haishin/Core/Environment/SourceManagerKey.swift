//
//  SourceManagerKey.swift
//  Miru
//
//  Created by Miru on 25.01.26.
//

import SwiftUI

/// Environment key for sharing SourceManager across the app.
struct SourceManagerKey: EnvironmentKey {
    static let defaultValue: SourceManager? = nil
}

extension EnvironmentValues {
    var sourceManager: SourceManager? {
        get { self[SourceManagerKey.self] }
        set { self[SourceManagerKey.self] = newValue }
    }
}
