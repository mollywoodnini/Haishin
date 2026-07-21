//
//  StandardAnimeCard.swift
//  Haishin
//
//  Created by Haishin on 24.01.26.
//

import SwiftUI
import Kingfisher


//#################################################################################
// MARK: - SizingMode
//#################################################################################

/// Defines how a StandardAnimeCard should size itself.
enum StandardAnimeCardSizingMode {
    /// Fixed width card, suitable for horizontal scroll sections.
    case fixed
    /// Flexible width card that fills available space, suitable for grids.
    case flexible
}


//#################################################################################
// MARK: - StandardAnimeCard
//#################################################################################

/// A standard anime card for horizontal sections showing cover and title.
struct StandardAnimeCard: View {


    //#################################################################################
    // MARK: - Constants
    //#################################################################################

    private enum Constants {
        static let cardWidth: CGFloat = 140
        static let imageHeight: CGFloat = 200
        static let imageAspectRatio: CGFloat = 2 / 3
        static let textHeight: CGFloat = 60
    }


    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    private let title: String
    private let coverURL: URL?
    private let totalEpisodes: Int?
    private let subtitle: String?
    private let sizingMode: StandardAnimeCardSizingMode


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new standard anime card from a recommending item.
    init(item: RecommendingItem, sizingMode: StandardAnimeCardSizingMode = .fixed) {
        self.title = item.title
        self.coverURL = item.coverURL
        self.totalEpisodes = item.totalEpisodes
        self.subtitle = item.subtitle
        self.sizingMode = sizingMode
    }


    //#################################################################################
    // MARK: - Body
    //#################################################################################

    var body: some View {
        VStack(alignment: .leading, spacing: .spacingXXS) {
            imageView
            textView
        }
        .modifier(CardWidthModifier(sizingMode: sizingMode, width: Constants.cardWidth))
    }


    //#################################################################################
    // MARK: - Subviews
    //#################################################################################

    private var imageView: some View {
        ZStack(alignment: .bottomLeading) {
            KFImage(coverURL)
                .resizable()
                .placeholder {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.2))
                        .overlay {
                            Image(systemName: "photo")
                                .foregroundStyle(.secondary)
                        }
                }
                .aspectRatio(contentMode: .fill)
                .modifier(ImageFrameModifier(sizingMode: sizingMode,
                                             fixedWidth: Constants.cardWidth,
                                             fixedHeight: Constants.imageHeight,
                                             aspectRatio: Constants.imageAspectRatio))
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusS))

            if let totalEpisodes {
                Text("\(totalEpisodes) ep")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, .spacingXS)
                    .padding(.vertical, 3)
                    .background(.black.opacity(0.7))
                    .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusXS))
                    .padding(.spacingXXS)
            }
        }
    }

    private var textView: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer(minLength: 0)
        }
        .frame(height: Constants.textHeight)
    }
}


//#################################################################################
// MARK: - CardWidthModifier
//#################################################################################

/// A view modifier that applies width constraints based on sizing mode.
private struct CardWidthModifier: ViewModifier {
    let sizingMode: StandardAnimeCardSizingMode
    let width: CGFloat

    func body(content: Content) -> some View {
        switch sizingMode {
        case .fixed:
            content.frame(width: width)
        case .flexible:
            content.frame(maxWidth: .infinity)
        }
    }
}


//#################################################################################
// MARK: - ImageFrameModifier
//#################################################################################

/// A view modifier that applies image frame constraints based on sizing mode.
private struct ImageFrameModifier: ViewModifier {
    let sizingMode: StandardAnimeCardSizingMode
    let fixedWidth: CGFloat
    let fixedHeight: CGFloat
    let aspectRatio: CGFloat

    func body(content: Content) -> some View {
        switch sizingMode {
        case .fixed:
            content.frame(width: fixedWidth, height: fixedHeight)
        case .flexible:
            content.aspectRatio(aspectRatio, contentMode: .fit)
        }
    }
}
