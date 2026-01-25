//
//  TagsSectionView.swift
//  Miru
//
//  Created by Miru on 24.01.26.
//

import SwiftUI


//#################################################################################
// MARK: - TagsSectionView
//#################################################################################

/// A section view displaying tags in a flow layout.
struct TagsSectionView: View {

    //#################################################################################
    // MARK: - Types
    //#################################################################################

    /// A tag item.
    struct TagItem: Identifiable {

        //#################################################################################
        // MARK: - Properties
        //#################################################################################

        let id = UUID()
        let name: String
    }


    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    private let tags: [TagItem]


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new tags section view.
    /// - Parameter tags: The list of tags to display.
    init(tags: [TagItem]) {
        self.tags = tags
    }


    //#################################################################################
    // MARK: - Body
    //#################################################################################

    var body: some View {
        VStack(alignment: .leading, spacing: .spacingXS) {
            SectionHeader(title: "Tags")

            FlowLayout(spacing: .spacingXS) {
                ForEach(tags) { tag in
                    Text(tag.name)
                        .font(.caption)
                        .padding(.horizontal, .spacingXS)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.15))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, .spacingS)
        }
        .padding(.top, .spacingS)
    }
}
