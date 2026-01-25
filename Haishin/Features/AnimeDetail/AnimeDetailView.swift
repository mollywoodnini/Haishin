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
    @Environment(\.openURL) private var openURL
    @State private var navigateToEpisodes = false


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new detail view with an existing view model.
    /// - Parameter viewModel: The view model to use.
    init(viewModel: AnimeDetailViewModel) {
        self._viewModel = State(initialValue: viewModel)
    }

    /// Creates a new detail view.
    /// - Parameters:
    ///   - item: The recommending item to show details for.
    ///   - subscriptionService: The subscription service for managing subscriptions.
    ///   - watchProgressService: The watch progress service.
    ///   - sourceManager: The source manager for fetching episodes.
    init(item: RecommendingItem,
         subscriptionService: SubscriptionServiceProtocol,
         watchProgressService: WatchProgressServiceProtocol,
         sourceManager: SourceManaging) {
        self._viewModel = State(initialValue: AnimeDetailViewModel(item: item,
                                                                   subscriptionService: subscriptionService,
                                                                   watchProgressService: watchProgressService,
                                                                   sourceManager: sourceManager))
    }

    /// Creates a new detail view with explicit parameters.
    /// - Parameters:
    ///   - animeId: The AniList ID.
    ///   - title: The preview title.
    ///   - coverURL: The preview cover URL.
    ///   - subscriptionService: The subscription service for managing subscriptions.
    ///   - watchProgressService: The watch progress service.
    ///   - sourceManager: The source manager for fetching episodes.
    init(animeId: Int,
         title: String,
         coverURL: URL?,
         subscriptionService: SubscriptionServiceProtocol,
         watchProgressService: WatchProgressServiceProtocol,
         sourceManager: SourceManaging) {
        self._viewModel = State(initialValue: AnimeDetailViewModel(animeId: animeId,
                                                                   previewTitle: title,
                                                                   previewCoverURL: coverURL,
                                                                   subscriptionService: subscriptionService,
                                                                   watchProgressService: watchProgressService,
                                                                   sourceManager: sourceManager))
    }


    //#################################################################################
    // MARK: - Body
    //#################################################################################

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                AnimeDetailHeaderView(displayTitle: viewModel.displayTitle,
                                      alternativeTitles: viewModel.alternativeTitles,
                                      bannerURL: viewModel.anime?.bannerURL,
                                      coverURL: viewModel.displayCoverURL,
                                      viewEpisodesButton: AnyView(viewEpisodesButton))

                if viewModel.isLoading && viewModel.anime == nil {
                    AnimeDetailLoadingView()
                } else if let error = viewModel.error, viewModel.anime == nil {
                    AnimeDetailErrorView(error: error) {
                        await viewModel.retry()
                    }
                } else {
                    contentSections
                }
            }
        }
        .ignoresSafeArea(edges: .top)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        viewModel.toggleSubscription()
                    } label: {
                        Label(viewModel.isSubscribed ? "Unsubscribe" : "Subscribe",
                              systemImage: viewModel.isSubscribed ? "bell.slash" : "bell")
                    }

                    if let siteUrl = viewModel.anime?.siteUrl {
                        Button {
                            openURL(siteUrl)
                        } label: {
                            Label("View on AniList", systemImage: "safari")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .navigationDestination(isPresented: $navigateToEpisodes) {
            if let episodeListViewModel = viewModel.makeEpisodeListViewModel() {
                EpisodeListView(viewModel: episodeListViewModel)
            } else {
                Text("Error: Missing required data for episodes view")
            }
        }
        .task {
            await viewModel.loadDetails()
        }
    }


    //#################################################################################
    // MARK: - Content Sections
    //#################################################################################

    @ViewBuilder
    private var contentSections: some View {
        if let synopsis = viewModel.anime?.synopsis, !synopsis.isEmpty {
            SynopsisSectionView(synopsis: synopsis,
                                isExpanded: $viewModel.isSynopsisExpanded)
        }

        if let genres = viewModel.anime?.genres, !genres.isEmpty {
            GenresSectionView(genres: genres)
        }

        if viewModel.formattedScore != nil {
            RatingsStatisticsSectionView(formattedScore: viewModel.formattedScore,
                                         popularityString: viewModel.popularityString,
                                         favoritesString: viewModel.favoritesString)
        }

        if !viewModel.informationItems.isEmpty {
            InformationSectionView(items: viewModel.informationItems.map {
                InformationSectionView.Item(key: $0.key, value: $0.value)
            })
        }

        if let nextEpisode = viewModel.anime?.nextAiringEpisode {
            UpcomingSectionView(episode: nextEpisode)
        }

        if !viewModel.mainCharacters.isEmpty || !viewModel.supportingCharacters.isEmpty {
            CharactersSectionView(characters: viewModel.mainCharacters + viewModel.supportingCharacters)
        }

        if let relations = viewModel.anime?.relations, !relations.isEmpty {
            RelationsSectionView(relations: relations) { relation in
                AnimeDetailView(viewModel: viewModel.makeRelatedAnimeDetailViewModel(relation: relation))
            }
        }

        if let recommendations = viewModel.anime?.recommendations, !recommendations.isEmpty {
            RecommendationsSectionView(recommendations: recommendations) { rec in
                AnimeDetailView(viewModel: viewModel.makeRecommendationDetailViewModel(recommendation: rec))
            }
        }

        if !viewModel.streamingLinks.isEmpty {
            StreamingLinksSectionView(links: viewModel.streamingLinks.map {
                StreamingLinksSectionView.LinkItem(site: $0.site, url: $0.url, icon: $0.icon)
            })
        }

        if !viewModel.displayTags.isEmpty {
            TagsSectionView(tags: viewModel.displayTags.map {
                TagsSectionView.TagItem(name: $0.name)
            })
        }

        Spacer()
            .frame(height: .spacingL)
    }


    //#################################################################################
    // MARK: - View Episodes Button
    //#################################################################################

    private var viewEpisodesButton: some View {
        ViewEpisodesButton(animeTitle: viewModel.displayTitle,
                           selectedSourceId: Binding(
                               get: { viewModel.selectedSourceId },
                               set: { viewModel.selectedSourceId = $0 }
                           ),
                           installedSources: viewModel.installedSources,
                           validateSourceSelection: viewModel.validateSourceSelection) {
            navigateToEpisodes = true
        }
    }
}


//#################################################################################
// MARK: - Preview
//#################################################################################

#Preview {
    NavigationStack {
        AnimeDetailView(item: RecommendingItem(id: "1",
                                   title: "Attack on Titan",
                                   subtitle: "MAPPA",
                                   coverURL: URL(string: "https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx16498-73IhOXpJZiMF.jpg"),
                                   anilistId: 16498),
                        subscriptionService: SubscriptionService.shared,
                        watchProgressService: WatchProgressService.shared,
                        sourceManager: SourceManager())
    }
}
