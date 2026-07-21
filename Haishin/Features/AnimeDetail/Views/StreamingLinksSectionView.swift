//
//  StreamingLinksSectionView.swift
//  Haishin
//
//  Created by Haishin on 24.01.26.
//

import Kingfisher
import SwiftUI


//#################################################################################
// MARK: - StreamingLinksSectionView
//#################################################################################

/// A section view displaying external streaming links.
struct StreamingLinksSectionView: View {

    //#################################################################################
    // MARK: - Types
    //#################################################################################

    /// A streaming link item.
    struct LinkItem: Identifiable {

        //#################################################################################
        // MARK: - Properties
        //#################################################################################

        let id = UUID()
        let site: String
        let url: URL
        let icon: URL?
    }


    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    private let links: [LinkItem]


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new streaming links section view.
    /// - Parameter links: The list of streaming links to display.
    init(links: [LinkItem]) {
        self.links = links
    }


    //#################################################################################
    // MARK: - Body
    //#################################################################################

    var body: some View {
        VStack(alignment: .leading, spacing: .spacingXS) {
            SectionHeader(title: "Watch On")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: .spacingS) {
                    ForEach(links) { link in
                        Link(destination: link.url) {
                            HStack(spacing: .spacingXS) {
                                if let iconURL = link.icon {
                                    KFImage(iconURL)
                                        .resizable()
                                        .placeholder {
                                            Image(systemName: "play.rectangle.fill")
                                        }
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 20, height: 20)
                                } else {
                                    Image(systemName: "play.rectangle.fill")
                                }

                                Text(link.site)
                                    .font(.subheadline)
                            }
                            .padding(.horizontal, .spacingS)
                            .padding(.vertical, .spacingXS)
                            .background(Color.secondary.opacity(0.15))
                            .clipShape(Capsule())
                        }
                    }
                }
                .padding(.horizontal, .spacingS)
            }
        }
        .padding(.top, .spacingS)
    }
}
