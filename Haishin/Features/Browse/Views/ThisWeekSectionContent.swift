//
//  ThisWeekSectionContent.swift
//  Miru
//
//  Created by Miru on 24.01.26.
//

import SwiftUI


//#################################################################################
// MARK: - ThisWeekSectionContent
//#################################################################################

/// Content view for "This Week" calendar-style section with horizontal scrolling cards.
struct ThisWeekSectionContent: View {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    private let items: [RecommendingItem]


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new this week section content view.
    /// - Parameter items: The recommending items to display.
    init(items: [RecommendingItem]) {
        self.items = items
    }


    //#################################################################################
    // MARK: - Body
    //#################################################################################

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: .spacingS) {
                ForEach(items) { item in
                    NavigationLink {
                        AnimeDetailView(item: item)
                    } label: {
                        ThisWeekCard(item: item)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, .spacingS)
        }
    }
}
