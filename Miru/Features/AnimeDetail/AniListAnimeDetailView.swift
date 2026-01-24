//
//  AniListAnimeDetailView.swift
//  Miru
//
//  Created by Miru on 24.01.26.
//

import SwiftUI


//#################################################################################
// MARK: - AniListAnimeDetailView
//#################################################################################

/// A detailed view for anime fetched from AniList.
/// Inspired by NineAnimator's AnimeInformationTableViewController design.
struct AniListAnimeDetailView: View {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    @State private var viewModel: AniListAnimeDetailViewModel
    @Environment(\.dismiss) private var dismiss


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new detail view.
    /// - Parameter item: The recommending item to show details for.
    init(item: RecommendingItem) {
        self._viewModel = State(initialValue: AniListAnimeDetailViewModel(item: item))
    }

    /// Creates a new detail view with explicit parameters.
    /// - Parameters:
    ///   - animeId: The AniList ID.
    ///   - title: The preview title.
    ///   - coverURL: The preview cover URL.
    init(animeId: Int, title: String, coverURL: URL?) {
        self._viewModel = State(initialValue: AniListAnimeDetailViewModel(
            animeId: animeId,
            previewTitle: title,
            previewCoverURL: coverURL
        ))
    }


    //#################################################################################
    // MARK: - Body
    //#################################################################################

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                headerSection

                if viewModel.isLoading && viewModel.anime == nil {
                    loadingSection
                } else if let error = viewModel.error, viewModel.anime == nil {
                    errorSection(error: error)
                } else {
                    contentSections
                }
            }
        }
        .ignoresSafeArea(edges: .top)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .task {
            await viewModel.loadDetails()
        }
    }


    //#################################################################################
    // MARK: - Header Section
    //#################################################################################

    private var headerSection: some View {
        ZStack(alignment: .bottom) {
            // Banner/Wallpaper
            bannerImage

            // Gradient overlay
            LinearGradient(
                colors: [.clear, .clear, Color(.systemBackground)],
                startPoint: .top,
                endPoint: .bottom
            )

            // Content overlay
            HStack(alignment: .bottom, spacing: .spacingS) {
                // Cover image
                coverImage

                // Title and info
                VStack(alignment: .leading, spacing: .spacingXXS) {
                    Spacer()

                    Text(viewModel.displayTitle)
                        .font(.title2)
                        .fontWeight(.bold)
                        .lineLimit(3)

                    if let altTitles = viewModel.alternativeTitles {
                        Text(altTitles)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, .spacingS)
            }
            .padding(.horizontal, .spacingS)
            .padding(.bottom, .spacingXS)
        }
        .frame(height: 280)
    }

    private var bannerImage: some View {
        Group {
            if let bannerURL = viewModel.anime?.bannerURL {
                AsyncImage(url: bannerURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    coverAsBackground
                }
            } else {
                coverAsBackground
            }
        }
        .frame(height: 280)
        .clipped()
        .opacity(0.4)
    }

    private var coverAsBackground: some View {
        AsyncImage(url: viewModel.displayCoverURL) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
                .blur(radius: 20)
        } placeholder: {
            Rectangle()
                .fill(Color.secondary.opacity(0.2))
        }
    }

    private var coverImage: some View {
        AsyncImage(url: viewModel.displayCoverURL) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            case .failure:
                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    }
            case .empty:
                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
                    .overlay {
                        ProgressView()
                    }
            @unknown default:
                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
            }
        }
        .frame(width: 120, height: 170)
        .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusS))
        .shadow(radius: 8)
    }


    //#################################################################################
    // MARK: - Loading & Error
    //#################################################################################

    private var loadingSection: some View {
        VStack(spacing: .spacingM) {
            ProgressView()
            Text("Loading details...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, .spacingL)
    }

    private func errorSection(error: Error) -> some View {
        VStack(spacing: .spacingS) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.secondary)

            Text("Failed to load details")
                .font(.headline)

            Text(error.localizedDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Retry") {
                Task {
                    await viewModel.retry()
                }
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .padding(.spacingM)
    }


    //#################################################################################
    // MARK: - Content Sections
    //#################################################################################

    @ViewBuilder
    private var contentSections: some View {
        // Quick info bar
        quickInfoSection

        // Synopsis
        if let synopsis = viewModel.anime?.synopsis, !synopsis.isEmpty {
            synopsisSection(synopsis: synopsis)
        }

        // Genres
        if let genres = viewModel.anime?.genres, !genres.isEmpty {
            genresSection(genres: genres)
        }

        // Next airing episode
        if let nextEpisode = viewModel.anime?.nextAiringEpisode {
            nextEpisodeSection(episode: nextEpisode)
        }

        // Characters
        if !viewModel.mainCharacters.isEmpty || !viewModel.supportingCharacters.isEmpty {
            charactersSection
        }

        // Related anime
        if let relations = viewModel.anime?.relations, !relations.isEmpty {
            relationsSection(relations: relations)
        }

        // Recommendations
        if let recommendations = viewModel.anime?.recommendations, !recommendations.isEmpty {
            recommendationsSection(recommendations: recommendations)
        }

        // External links
        if !viewModel.streamingLinks.isEmpty {
            streamingLinksSection
        }

        // Tags
        if !viewModel.displayTags.isEmpty {
            tagsSection
        }

        // Bottom spacing
        Spacer()
            .frame(height: .spacingL)
    }


    //#################################################################################
    // MARK: - Quick Info Section
    //#################################################################################

    private var quickInfoSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: .spacingS) {
                if let score = viewModel.scoreString {
                    QuickInfoChip(icon: "star.fill", text: score, tint: .yellow)
                }

                if let status = viewModel.anime?.status {
                    QuickInfoChip(
                        icon: status == .releasing ? "play.circle.fill" : "checkmark.circle.fill",
                        text: status.displayString,
                        tint: status == .releasing ? .green : .blue
                    )
                }

                if let format = viewModel.anime?.format {
                    QuickInfoChip(icon: "tv", text: format.displayString, tint: .purple)
                }

                if let episodes = viewModel.episodeCountString {
                    QuickInfoChip(icon: "film.stack", text: episodes, tint: .orange)
                }

                if let season = viewModel.seasonYearString {
                    QuickInfoChip(icon: "calendar", text: season, tint: .cyan)
                }

                if let studio = viewModel.studioString {
                    QuickInfoChip(icon: "building.2", text: studio, tint: .pink)
                }
            }
            .padding(.horizontal, .spacingS)
            .padding(.vertical, .spacingXS)
        }
    }


    //#################################################################################
    // MARK: - Synopsis Section
    //#################################################################################

    private func synopsisSection(synopsis: String) -> some View {
        VStack(alignment: .leading, spacing: .spacingXS) {
            SectionHeader(title: "Synopsis")

            VStack(alignment: .leading, spacing: .spacingXS) {
                Text(synopsis)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(viewModel.isSynopsisExpanded ? nil : 4)

                Button(viewModel.isSynopsisExpanded ? "Show Less" : "Read More") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.isSynopsisExpanded.toggle()
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.accent)
            }
            .padding(.horizontal, .spacingS)
        }
        .padding(.top, .spacingS)
    }


    //#################################################################################
    // MARK: - Genres Section
    //#################################################################################

    private func genresSection(genres: [String]) -> some View {
        VStack(alignment: .leading, spacing: .spacingXS) {
            SectionHeader(title: "Genres")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: .spacingXS) {
                    ForEach(genres, id: \.self) { genre in
                        Text(genre)
                            .font(.subheadline)
                            .padding(.horizontal, .spacingS)
                            .padding(.vertical, .spacingXS)
                            .background(Color.highlight.opacity(0.15))
                            .foregroundStyle(.highlight)
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, .spacingS)
            }
        }
        .padding(.top, .spacingS)
    }


    //#################################################################################
    // MARK: - Next Episode Section
    //#################################################################################

    private func nextEpisodeSection(episode: AniListAiringEpisode) -> some View {
        VStack(alignment: .leading, spacing: .spacingXS) {
            SectionHeader(title: "Next Episode")

            HStack(spacing: .spacingS) {
                Image(systemName: "clock.badge.exclamationmark")
                    .font(.title2)
                    .foregroundStyle(.highlight)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Episode \(episode.episode)")
                        .font(.headline)

                    Text("Airing in \(episode.countdownString)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(.spacingS)
            .background(Color.highlight.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusS))
            .padding(.horizontal, .spacingS)
        }
        .padding(.top, .spacingS)
    }


    //#################################################################################
    // MARK: - Characters Section
    //#################################################################################

    private var charactersSection: some View {
        VStack(alignment: .leading, spacing: .spacingXS) {
            SectionHeader(title: "Characters")

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: .spacingS) {
                    ForEach(viewModel.mainCharacters + viewModel.supportingCharacters) { character in
                        CharacterCard(character: character)
                    }
                }
                .padding(.horizontal, .spacingS)
            }
        }
        .padding(.top, .spacingS)
    }


    //#################################################################################
    // MARK: - Relations Section
    //#################################################################################

    private func relationsSection(relations: [AniListRelation]) -> some View {
        VStack(alignment: .leading, spacing: .spacingXS) {
            SectionHeader(title: "Related")

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: .spacingS) {
                    ForEach(relations) { relation in
                        NavigationLink {
                            AniListAnimeDetailView(
                                animeId: relation.id,
                                title: relation.title,
                                coverURL: relation.coverURL
                            )
                        } label: {
                            RelationCard(relation: relation)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, .spacingS)
            }
        }
        .padding(.top, .spacingS)
    }


    //#################################################################################
    // MARK: - Recommendations Section
    //#################################################################################

    private func recommendationsSection(recommendations: [AniListRecommendation]) -> some View {
        VStack(alignment: .leading, spacing: .spacingXS) {
            SectionHeader(title: "You Might Also Like")

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: .spacingS) {
                    ForEach(recommendations) { rec in
                        NavigationLink {
                            AniListAnimeDetailView(
                                animeId: rec.id,
                                title: rec.title,
                                coverURL: rec.coverURL
                            )
                        } label: {
                            RecommendationCard(recommendation: rec)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, .spacingS)
            }
        }
        .padding(.top, .spacingS)
    }


    //#################################################################################
    // MARK: - Streaming Links Section
    //#################################################################################

    private var streamingLinksSection: some View {
        VStack(alignment: .leading, spacing: .spacingXS) {
            SectionHeader(title: "Watch On")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: .spacingS) {
                    ForEach(viewModel.streamingLinks) { link in
                        Link(destination: link.url) {
                            HStack(spacing: .spacingXS) {
                                if let iconURL = link.icon {
                                    AsyncImage(url: iconURL) { image in
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                    } placeholder: {
                                        Image(systemName: "play.rectangle.fill")
                                    }
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


    //#################################################################################
    // MARK: - Tags Section
    //#################################################################################

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: .spacingXS) {
            SectionHeader(title: "Tags")

            FlowLayout(spacing: .spacingXS) {
                ForEach(viewModel.displayTags) { tag in
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


//#################################################################################
// MARK: - Supporting Views
//#################################################################################

/// Section header with title.
private struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.title3)
            .fontWeight(.semibold)
            .padding(.horizontal, .spacingS)
    }
}

/// Quick info chip for the info bar.
private struct QuickInfoChip: View {
    let icon: String
    let text: String
    let tint: Color

    var body: some View {
        HStack(spacing: .spacingXXS) {
            Image(systemName: icon)
                .foregroundStyle(tint)
            Text(text)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, .spacingS)
        .padding(.vertical, .spacingXS)
        .background(tint.opacity(0.15))
        .clipShape(Capsule())
    }
}

/// Character card for the characters section.
private struct CharacterCard: View {
    let character: AniListCharacter

    var body: some View {
        VStack(spacing: .spacingXXS) {
            AsyncImage(url: character.imageURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
                    .overlay {
                        Image(systemName: "person.fill")
                            .foregroundStyle(.secondary)
                    }
            }
            .frame(width: 80, height: 100)
            .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusXS))

            VStack(spacing: 2) {
                Text(character.name)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)

                if let voiceActor = character.voiceActorName {
                    Text(voiceActor)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(width: 80)
        }
    }
}

/// Relation card for related anime.
private struct RelationCard: View {
    let relation: AniListRelation

    var body: some View {
        VStack(alignment: .leading, spacing: .spacingXXS) {
            ZStack(alignment: .bottomLeading) {
                AsyncImage(url: relation.coverURL) { image in
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
                .frame(width: 100, height: 140)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusXS))

                // Relation type badge
                Text(relation.relationType.displayString)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, .spacingXXS)
                    .padding(.vertical, 2)
                    .background(.black.opacity(0.7))
                    .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusXS))
                    .padding(4)
            }

            Text(relation.title)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(2)
                .frame(width: 100, alignment: .leading)
        }
    }
}

/// Recommendation card for similar anime.
private struct RecommendationCard: View {
    let recommendation: AniListRecommendation

    var body: some View {
        VStack(alignment: .leading, spacing: .spacingXXS) {
            AsyncImage(url: recommendation.coverURL) { image in
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
            .frame(width: 100, height: 140)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusXS))

            Text(recommendation.title)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(2)
                .frame(width: 100, alignment: .leading)
        }
    }
}

/// A simple flow layout for tags.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)

        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                      y: bounds.minY + result.positions[index].y),
                          proposal: .unspecified)
        }
    }

    private struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > maxWidth, x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }

                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing
                self.size.width = max(self.size.width, x)
            }

            self.size.height = y + rowHeight
        }
    }
}


//#################################################################################
// MARK: - Preview
//#################################################################################

#Preview {
    NavigationStack {
        AniListAnimeDetailView(
            item: RecommendingItem(
                id: "1",
                title: "Attack on Titan",
                subtitle: "MAPPA",
                coverURL: URL(string: "https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx16498-73IhOXpJZiMF.jpg"),
                anilistId: 16498
            )
        )
    }
}
