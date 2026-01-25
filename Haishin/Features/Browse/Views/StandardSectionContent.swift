//
//  StandardSectionContent.swift
//  Miru
//
//  Created by Miru on 24.01.26.
//

import SwiftUI


//#################################################################################
// MARK: - StandardSectionContent
//#################################################################################

/// Content view for standard horizontal scrolling section with anime cards.
struct StandardSectionContent: View {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    private let items: [RecommendingItem]


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new standard section content view.
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
                        AnimeDetailView(item: item,
                                        subscriptionService: SubscriptionService.shared,
                                        watchProgressService: WatchProgressService.shared)
                    } label: {
                        StandardAnimeCard(item: item)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, .spacingS)
        }
    }
}
