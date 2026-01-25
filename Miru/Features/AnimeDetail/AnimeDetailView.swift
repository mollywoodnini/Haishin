//
//  AnimeDetailView.swift
//  Miru
//
//  Created by Miru on 24.01.26.
//

import SwiftUI


//#################################################################################
// MARK: - AnimeDetailView
//#################################################################################

/// A detailed view for anime fetched from AniList.
struct AnimeDetailView: View {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    @State private var viewModel: AnimeDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.sourceManager) private var sourceManager
    @State private var isSynopsisTruncated = false
    @State private var showingSourcePicker = false
    @State private var navigateToEpisodes = false
    @State private var userPreferences = UserPreferences()


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new detail view.
    /// - Parameter item: The recommending item to show details for.
    init(item: RecommendingItem) {
        self._viewModel = State(initialValue: AnimeDetailViewModel(item: item))
    }

    /// Creates a new detail view with explicit parameters.
    /// - Parameters:
    ///   - animeId: The AniList ID.
    ///   - title: The preview title.
    ///   - coverURL: The preview cover URL.
    init(animeId: Int, title: String, coverURL: URL?) {
        self._viewModel = State(initialValue: AnimeDetailViewModel(
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
        .navigationDestination(isPresented: $navigateToEpisodes) {
            if let anime = viewModel.anime, 
               let sourceId = userPreferences.selectedSourceId,
               let sourceManager = sourceManager {
                let _ = print("[AnimeDetailView] Navigation destination triggered. Creating EpisodeListView")
                EpisodeListView(aniListAnime: anime, sourceId: sourceId, sourceManager: sourceManager)
            } else {
                let _ = print("[AnimeDetailView] Navigation destination triggered but conditions not met:")
                let _ = print("  anime: \(viewModel.anime != nil ? "exists" : "nil")")
                let _ = print("  sourceId: \(userPreferences.selectedSourceId ?? "nil")")
                let _ = print("  sourceManager: \(sourceManager != nil ? "exists" : "nil")")
                Text("Error: Missing required data for episodes view")
            }
        }
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
                .frame(maxWidth: .infinity)

            // Gradient overlay
            LinearGradient(
                colors: [.clear, .clear, Color(.systemBackground)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(maxWidth: .infinity)

            // Content overlay
            HStack(alignment: .bottom, spacing: .spacingS) {
                // Cover image
                coverImage

                // Title and info
                VStack(alignment: .leading, spacing: .spacingXXS) {
                    Text(viewModel.displayTitle)
                        .font(.title2)
                        .fontWeight(.bold)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    if let altTitles = viewModel.alternativeTitles {
                        Text(altTitles)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    
                    // View Episodes Button
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

    private var bannerImage: some View {
        Color.clear
            .overlay {
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
            }
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
        Color.clear
            .frame(width: 120, height: 170)
            .overlay {
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
            }
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
        // Synopsis
        if let synopsis = viewModel.anime?.synopsis, !synopsis.isEmpty {
            synopsisSection(synopsis: synopsis)
        }

        // Genres
        if let genres = viewModel.anime?.genres, !genres.isEmpty {
            genresSection(genres: genres)
        }

        // Ratings & Statistics
        if viewModel.formattedScore != nil {
            ratingsStatisticsSection
        }

        // Information
        if !viewModel.informationItems.isEmpty {
            informationSection
        }

        // Upcoming episodes
        if let nextEpisode = viewModel.anime?.nextAiringEpisode {
            upcomingSection(episode: nextEpisode)
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
    // MARK: - Ratings & Statistics Section
    //#################################################################################

    private var ratingsStatisticsSection: some View {
        VStack(alignment: .leading, spacing: .spacingXS) {
            SectionHeader(title: "Ratings & Statistics")

            HStack(spacing: .spacingL) {
                // Large score display
                if let score = viewModel.formattedScore {
                    VStack(spacing: .spacingXXS) {
                        Text(score)
                            .font(.system(size: 36, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)

                        Text("Average Score")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(minWidth: 80)
                }

                // Stats
                VStack(alignment: .leading, spacing: .spacingXS) {
                    if let popularity = viewModel.popularityString {
                        HStack {
                            Image(systemName: "person.2.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(popularity) users")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let favorites = viewModel.favoritesString {
                        HStack {
                            Image(systemName: "heart.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(favorites) favorites")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()
            }
            .padding(.spacingS)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusS))
            .padding(.horizontal, .spacingS)
        }
        .padding(.top, .spacingS)
    }


    //#################################################################################
    // MARK: - Information Section
    //#################################################################################

    private var informationSection: some View {
        VStack(alignment: .leading, spacing: .spacingXS) {
            SectionHeader(title: "Information")

            VStack(spacing: 0) {
                ForEach(Array(viewModel.informationItems.enumerated()), id: \.offset) { index, item in
                    HStack {
                        Text(item.key)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Text(item.value)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                    }
                    .padding(.vertical, .spacingXS)
                    .padding(.horizontal, .spacingS)

                    if index < viewModel.informationItems.count - 1 {
                        Divider()
                            .padding(.leading, .spacingS)
                    }
                }
            }
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusS))
            .padding(.horizontal, .spacingS)
        }
        .padding(.top, .spacingS)
    }


    //#################################################################################
    // MARK: - Upcoming Section
    //#################################################################################

    private func upcomingSection(episode: AniListAiringEpisode) -> some View {
        VStack(alignment: .leading, spacing: .spacingXS) {
            SectionHeader(title: "Upcoming")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: .spacingS) {
                    UpcomingEpisodeCard(episode: episode)
                }
                .padding(.horizontal, .spacingS)
            }
        }
        .padding(.top, .spacingS)
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
                    .background {
                        GeometryReader { visibleGeometry in
                            Color.clear
                                .overlay {
                                    Text(synopsis)
                                        .font(.body)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .background {
                                            GeometryReader { fullGeometry in
                                                Color.clear.onAppear {
                                                    isSynopsisTruncated = fullGeometry.size.height > visibleGeometry.size.height
                                                }
                                                .onChange(of: viewModel.isSynopsisExpanded) { _, _ in
                                                    isSynopsisTruncated = fullGeometry.size.height > visibleGeometry.size.height
                                                }
                                            }
                                        }
                                        .hidden()
                                }
                        }
                    }

                if isSynopsisTruncated || viewModel.isSynopsisExpanded {
                    Button(viewModel.isSynopsisExpanded ? "Show Less" : "Read More") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.isSynopsisExpanded.toggle()
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.accent)
                }
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
                            AnimeDetailView(
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
                            AnimeDetailView(
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


    //#################################################################################
    // MARK: - View Episodes Button
    //#################################################################################

    private var viewEpisodesButton: some View {
        Button {
            print("[AnimeDetailView] VIEW EPISODES button tapped")
            print("  selectedSourceId: \(userPreferences.selectedSourceId ?? "nil")")
            print("  sourceManager: \(sourceManager != nil ? "exists" : "nil")")
            
            // Validate that the selected source actually exists
            if let selectedId = userPreferences.selectedSourceId,
               let sourceManager = sourceManager {
                let sourceExists = sourceManager.installedSources.contains(where: { $0.id == selectedId })
                print("[AnimeDetailView] Source '\(selectedId)' exists: \(sourceExists)")
                
                if sourceExists {
                    // Source exists, navigate directly
                    print("[AnimeDetailView] Source valid, setting navigateToEpisodes = true")
                    navigateToEpisodes = true
                } else {
                    // Source doesn't exist, clear it and show picker
                    print("[AnimeDetailView] Source invalid, clearing and showing picker")
                    userPreferences.selectedSourceId = nil
                    showingSourcePicker = true
                }
            } else {
                // No source selected, show picker
                print("[AnimeDetailView] No source selected, showing picker")
                showingSourcePicker = true
            }
        } label: {
            Text("VIEW EPISODES")
                .font(.system(size: 15, weight: .bold))
        }
        .buttonStyle(.borderedProminent)
        .sheet(isPresented: $showingSourcePicker) {
            if let sourceManager {
                SourcePickerView(animeTitle: viewModel.displayTitle,
                                 selectedSourceId: $userPreferences.selectedSourceId,
                                 onSourceSelected: {
                                     print("[AnimeDetailView] Source selected from picker, dismissing sheet")
                                     showingSourcePicker = false
                                     // Navigate to episodes view after sheet dismisses
                                     DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                         print("[AnimeDetailView] Setting navigateToEpisodes = true after delay")
                                         navigateToEpisodes = true
                                     }
                                 },
                                 sourceManager: sourceManager)
            }
        }
    }
}


//#################################################################################
// MARK: - Preview
//#################################################################################

#Preview {
    NavigationStack {
        AnimeDetailView(
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
