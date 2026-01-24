//
//  BrowseView.swift
//  Miru
//
//  Created by Miru on 24.01.26.
//

import SwiftUI


//#################################################################################
// MARK: - BrowseView
//#################################################################################

/// The main browse view showing anime recommendations from AniList.
struct BrowseView: View {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    @State private var viewModel: BrowseViewModel
    private let sourceManager: SourceManaging


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new browse view.
    /// - Parameter sourceManager: The source manager to use.
    init(sourceManager: SourceManaging) {
        self.sourceManager = sourceManager
        self._viewModel = State(initialValue: BrowseViewModel(sourceManager: sourceManager))
    }


    //#################################################################################
    // MARK: - Body
    //#################################################################################

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: .spacingM) {
                    ForEach(viewModel.sections) { section in
                        RecommendationSectionView(section: section)
                    }
                }
                .padding(.vertical, .spacingS)
            }
            .navigationTitle("Browse")
            .task {
                await viewModel.loadContent()
            }
            .refreshable {
                await viewModel.refresh()
            }
            .overlay {
                if viewModel.isLoading && viewModel.sections.allSatisfy({ $0.items.isEmpty }) {
                    ProgressView()
                }
            }
        }
    }
}


//#################################################################################
// MARK: - RecommendationSectionView
//#################################################################################

/// A view displaying a single recommendation section.
private struct RecommendationSectionView: View {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    let section: RecommendationSection


    //#################################################################################
    // MARK: - Body
    //#################################################################################

    var body: some View {
        VStack(alignment: .leading, spacing: .spacingXS) {
            sectionHeader

            switch section.loadingState {
            case .loading where section.items.isEmpty:
                loadingView
            case .failed(let message):
                errorView(message: message)
            default:
                sectionContent
            }
        }
    }

    private var sectionHeader: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: .spacingXXS) {
                Text(section.title)
                    .font(.title2)
                    .fontWeight(.bold)

                if let subtitle = section.subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Action button based on section style
            switch section.style {
            case .thisWeek:
                NavigationLink(destination: ScheduleView()) {
                    Text("Show Schedule")
                        .font(.subheadline)
                        .foregroundStyle(.accent)
                }
            case .standard, .wide:
                if let listType = section.listType {
                    NavigationLink(destination: AnimeListView(title: section.title, listType: listType)) {
                        Text("View More")
                            .font(.subheadline)
                            .foregroundStyle(.accent)
                    }
                }
            }
        }
        .padding(.horizontal, .spacingS)
    }

    private var loadingView: some View {
        HStack {
            Spacer()
            ProgressView()
            Spacer()
        }
        .frame(height: 200)
    }

    private func errorView(message: String) -> some View {
        HStack {
            Spacer()
            VStack(spacing: .spacingXS) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.title)
                    .foregroundStyle(.secondary)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Spacer()
        }
        .padding(.spacingS)
    }

    @ViewBuilder
    private var sectionContent: some View {
        if section.items.isEmpty {
            EmptyView()
        } else {
            switch section.style {
            case .thisWeek:
                ThisWeekSectionContent(items: section.items)
            case .standard, .wide:
                StandardSectionContent(items: section.items)
            }
        }
    }
}


//#################################################################################
// MARK: - ThisWeekSectionContent
//#################################################################################

/// Content view for "This Week" calendar-style section.
private struct ThisWeekSectionContent: View {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    let items: [RecommendingItem]


    //#################################################################################
    // MARK: - Body
    //#################################################################################

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: .spacingS) {
                ForEach(items) { item in
                    NavigationLink {
                        AniListAnimeDetailView(item: item)
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


//#################################################################################
// MARK: - ThisWeekCard
//#################################################################################

/// A card for the "This Week" section showing air date and episode info.
private struct ThisWeekCard: View {

    //#################################################################################
    // MARK: - Constants
    //#################################################################################

    private struct Constants {
        static let cardWidth: CGFloat = 300
        static let cardHeight: CGFloat = 200
        static let imageWidth: CGFloat = 120
    }


    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    let item: RecommendingItem


    //#################################################################################
    // MARK: - Body
    //#################################################################################

    var body: some View {
        HStack(spacing: .spacingS) {
            // Cover image with episode badge overlay
            ZStack(alignment: .bottomLeading) {
                AsyncImage(url: item.coverURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.2))
                        .overlay {
                            Image(systemName: "photo")
                                .foregroundStyle(.secondary)
                        }
                }
                .frame(width: Constants.imageWidth, height: Constants.cardHeight)
                .clipped()
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: .cornerRadiusM,
                        bottomLeadingRadius: .cornerRadiusM,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: 0
                    )
                )

                // Episode badge
                if let caption = item.caption {
                    Text(caption)
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

            // Info
            VStack(alignment: .leading, spacing: .spacingXXS) {
                if let date = item.subtitle {
                    Text(date)
                        .font(.subheadline)
                        .foregroundStyle(.highlight)
                }

                Text(item.title)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(2)

                if let synopsis = item.synopsis {
                    Text(synopsis)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, .spacingXS)
            .padding(.trailing, .spacingXS)
        }
        .frame(width: Constants.cardWidth, height: Constants.cardHeight)
        .background(Color.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusM))
    }
}


//#################################################################################
// MARK: - StandardSectionContent
//#################################################################################

/// Content view for standard horizontal scrolling section.
private struct StandardSectionContent: View {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    let items: [RecommendingItem]


    //#################################################################################
    // MARK: - Body
    //#################################################################################

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: .spacingS) {
                ForEach(items) { item in
                    NavigationLink {
                        AniListAnimeDetailView(item: item)
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


//#################################################################################
// MARK: - StandardAnimeCard
//#################################################################################

/// A standard anime card for horizontal sections.
private struct StandardAnimeCard: View {

    //#################################################################################
    // MARK: - Constants
    //#################################################################################

    private struct Constants {
        static let cardWidth: CGFloat = 140
        static let imageHeight: CGFloat = 200
        static let textHeight: CGFloat = 60
    }


    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    let item: RecommendingItem


    //#################################################################################
    // MARK: - Body
    //#################################################################################

    var body: some View {
        VStack(alignment: .leading, spacing: .spacingXXS) {
            // Image with fixed height at top
            ZStack(alignment: .bottomLeading) {
                AsyncImage(url: item.coverURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.2))
                        .overlay {
                            Image(systemName: "photo")
                                .foregroundStyle(.secondary)
                        }
                }
                .frame(width: Constants.cardWidth, height: Constants.imageHeight)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusS))

                // Episode count badge if available
                if let totalEpisodes = item.totalEpisodes {
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

            // Text content with spacer to push to bottom
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .frame(width: Constants.cardWidth, alignment: .leading)

                if let subtitle = item.subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .frame(width: Constants.cardWidth, alignment: .leading)
                }

                Spacer(minLength: 0)
            }
            .frame(height: Constants.textHeight)
        }
        .frame(width: Constants.cardWidth)
    }
}


//#################################################################################
// MARK: - Preview
//#################################################################################

#Preview {
    BrowseView(sourceManager: SourceManager())
}
