//
//  AnimeDetailHeaderView.swift
//  Miru
//
//  Created by Miru on 24.01.26.
//

import Kingfisher
import SwiftUI


//#################################################################################
// MARK: - AnimeDetailHeaderView
//#################################################################################

/// A header view displaying the anime banner, cover image, and title.
struct AnimeDetailHeaderView: View {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    private let displayTitle: String
    private let alternativeTitles: String?
    private let bannerURL: URL?
    private let coverURL: URL?
    private let viewEpisodesButton: AnyView


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new anime detail header view.
    /// - Parameters:
    ///   - displayTitle: The main title to display.
    ///   - alternativeTitles: Optional alternative titles.
    ///   - bannerURL: The URL for the banner image.
    ///   - coverURL: The URL for the cover image.
    ///   - viewEpisodesButton: The button view for viewing episodes.
    init(displayTitle: String,
         alternativeTitles: String?,
         bannerURL: URL?,
         coverURL: URL?,
         viewEpisodesButton: AnyView) {
        self.displayTitle = displayTitle
        self.alternativeTitles = alternativeTitles
        self.bannerURL = bannerURL
        self.coverURL = coverURL
        self.viewEpisodesButton = viewEpisodesButton
    }


    //#################################################################################
    // MARK: - Body
    //#################################################################################

    var body: some View {
        ZStack(alignment: .bottom) {
            bannerImage
                .frame(maxWidth: .infinity)

            LinearGradient(colors: [.clear, .clear, Color(.systemBackground)],
                           startPoint: .top,
                           endPoint: .bottom)
                .frame(maxWidth: .infinity)

            HStack(alignment: .bottom, spacing: .spacingS) {
                coverImage

                VStack(alignment: .leading, spacing: .spacingXXS) {
                    Text(displayTitle)
                        .font(.title2)
                        .fontWeight(.bold)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    if let altTitles = alternativeTitles {
                        Text(altTitles)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    viewEpisodesButton
                        .padding(.top, .spacingXS)
                }
                .frame(maxWidth: .infinity, alignment: .bottomLeading)
                .padding(.bottom, .spacingS)
            }
            .padding(.horizontal, .spacingS)
            .padding(.bottom, .spacingXS)
            .frame(maxWidth: .infinity)
        }
        .frame(height: 280)
    }


    //#################################################################################
    // MARK: - Private Views
    //#################################################################################

    private var bannerImage: some View {
        Color.clear
            .overlay {
                Group {
                    if let bannerURL {
                        KFImage(bannerURL)
                            .resizable()
                            .placeholder {
                                coverAsBackground
                            }
                            .aspectRatio(contentMode: .fill)
                    } else {
                        coverAsBackground
                    }
                }
            }
            .clipped()
            .opacity(0.4)
    }

    private var coverAsBackground: some View {
        KFImage(coverURL)
            .resizable()
            .placeholder {
                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
            }
            .aspectRatio(contentMode: .fill)
            .blur(radius: 20)
    }

    private var coverImage: some View {
        Color.clear
            .frame(width: 120, height: 170)
            .overlay {
                KFImage(coverURL)
                    .resizable()
                    .placeholder {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.2))
                            .overlay {
                                ProgressView()
                            }
                    }
                    .aspectRatio(contentMode: .fill)
            }
            .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusS))
            .shadow(radius: 8)
    }
}
