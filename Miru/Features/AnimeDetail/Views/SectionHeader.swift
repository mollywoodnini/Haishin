//
//  SectionHeader.swift
//  Miru
//
//  Created by Miru on 24.01.26.
//

import SwiftUI


//#################################################################################
// MARK: - SectionHeader
//#################################################################################

/// A section header view with a title.
struct SectionHeader: View {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    private let title: String


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new section header.
    /// - Parameter title: The title to display.
    init(title: String) {
        self.title = title
    }


    //#################################################################################
    // MARK: - Body
    //#################################################################################

    var body: some View {
        Text(title)
            .font(.title3)
            .fontWeight(.semibold)
            .padding(.horizontal, .spacingS)
    }
}
