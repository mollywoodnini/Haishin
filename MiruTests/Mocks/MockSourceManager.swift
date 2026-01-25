//
//  MockSourceManager.swift
//  MiruTests
//
//  Created by Miru on 24.01.26.
//

import Foundation
@testable import Miru

/// Mock implementation of SourceManaging for testing.
final class MockSourceManager: SourceManaging {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    var installedSources: [InstalledSource] = []
    var repositories: [SourceRepository] = []
    var isLoading = false
    var lastError: Error?


    //#################################################################################
    // MARK: - Stub Configuration
    //#################################################################################

    /// Stub for getPopular responses.
    var getPopularResult: Result<[AnimePreview], Error> = .success([])

    /// Stub for getLatest responses.
    var getLatestResult: Result<[AnimePreview], Error> = .success([])

    /// Stub for search responses.
    var searchResult: Result<[AnimePreview], Error> = .success([])

    /// Stub for getAnimeDetails responses.
    var getAnimeDetailsResult: Result<Anime, Error> = .failure(MockError.notConfigured)

    /// Stub for getVideoSources responses.
    var getVideoSourcesResult: Result<PlaybackInfo, Error> = .failure(MockError.notConfigured)


    //#################################################################################
    // MARK: - Call Tracking
    //#################################################################################

    /// Number of times loadInstalledSources was called.
    var loadInstalledSourcesCallCount = 0

    /// Number of times addRepository was called.
    var addRepositoryCallCount = 0

    /// URLs passed to addRepository.
    var addRepositoryURLs: [URL] = []

    /// Number of times installSource was called.
    var installSourceCallCount = 0

    /// Sources passed to installSource.
    var installedSourceInfos: [SourceInfo] = []

    /// Number of times uninstallSource was called.
    var uninstallSourceCallCount = 0

    /// Source IDs passed to uninstallSource.
    var uninstalledSourceIds: [String] = []

    /// Number of times getPopular was called.
    var getPopularCallCount = 0

    /// Number of times getLatest was called.
    var getLatestCallCount = 0

    /// Number of times search was called.
    var searchCallCount = 0

    /// Queries passed to search.
    var searchQueries: [String] = []

    /// Number of times getAnimeDetails was called.
    var getAnimeDetailsCallCount = 0

    /// Number of times getVideoSources was called.
    var getVideoSourcesCallCount = 0


    //#################################################################################
    // MARK: - SourceManaging Methods
    //#################################################################################

    func loadInstalledSources() async {
        loadInstalledSourcesCallCount += 1
    }

    func addRepository(url: URL) async throws {
        addRepositoryCallCount += 1
        addRepositoryURLs.append(url)
    }

    func installSource(_ source: SourceInfo, from repository: SourceRepository) async throws {
        installSourceCallCount += 1
        installedSourceInfos.append(source)
    }

    func uninstallSource(sourceId: String) throws {
        uninstallSourceCallCount += 1
        uninstalledSourceIds.append(sourceId)
        installedSources.removeAll { $0.id == sourceId }
    }

    func getPopular(sourceId: String, page: Int) async throws -> [AnimePreview] {
        getPopularCallCount += 1
        return try getPopularResult.get()
    }

    func getLatest(sourceId: String, page: Int) async throws -> [AnimePreview] {
        getLatestCallCount += 1
        return try getLatestResult.get()
    }

    func search(sourceId: String, query: String, page: Int) async throws -> [AnimePreview] {
        searchCallCount += 1
        searchQueries.append(query)
        return try searchResult.get()
    }

    func getAnimeDetails(sourceId: String, url: String) async throws -> Anime {
        getAnimeDetailsCallCount += 1
        return try getAnimeDetailsResult.get()
    }

    func getVideoSources(sourceId: String, episodeId: String, url: String) async throws -> PlaybackInfo {
        getVideoSourcesCallCount += 1
        return try getVideoSourcesResult.get()
    }
}


//#################################################################################
// MARK: - MockError
//#################################################################################

/// Errors used in mock testing.
enum MockError: Error {
    case notConfigured
    case testError
}


//#################################################################################
// MARK: - MockAniListService
//#################################################################################

/// Mock implementation of AniListServicing for testing.
final class MockAniListService: AniListServicing {

    //#################################################################################
    // MARK: - Stub Configuration
    //#################################################################################

    var fetchThisWeekResult: Result<[RecommendingItem], Error> = .success([])
    var fetchTrendingResult: Result<PaginatedResponse, Error> = .success(PaginatedResponse(items: [], hasNextPage: false, currentPage: 1))
    var fetchSeasonalResult: Result<PaginatedResponse, Error> = .success(PaginatedResponse(items: [], hasNextPage: false, currentPage: 1))
    var fetchAnimeDetailsResult: Result<AniListAnimeDetail, Error> = .failure(MockError.notConfigured)


    //#################################################################################
    // MARK: - Call Tracking
    //#################################################################################

    var fetchThisWeekCallCount = 0
    var fetchTrendingCallCount = 0
    var fetchTrendingPages: [Int] = []
    var fetchSeasonalCallCount = 0
    var fetchSeasonalPages: [Int] = []
    var fetchAnimeDetailsCallCount = 0
    var fetchAnimeDetailsIds: [Int] = []


    //#################################################################################
    // MARK: - AniListServicing Methods
    //#################################################################################

    func fetchThisWeek() async throws -> [RecommendingItem] {
        fetchThisWeekCallCount += 1
        return try fetchThisWeekResult.get()
    }

    func fetchTrending(page: Int) async throws -> PaginatedResponse {
        fetchTrendingCallCount += 1
        fetchTrendingPages.append(page)
        return try fetchTrendingResult.get()
    }

    func fetchSeasonal(page: Int) async throws -> PaginatedResponse {
        fetchSeasonalCallCount += 1
        fetchSeasonalPages.append(page)
        return try fetchSeasonalResult.get()
    }

    func fetchAnimeDetails(id: Int) async throws -> AniListAnimeDetail {
        fetchAnimeDetailsCallCount += 1
        fetchAnimeDetailsIds.append(id)
        return try fetchAnimeDetailsResult.get()
    }
}


//#################################################################################
// MARK: - Test Fixtures
//#################################################################################

/// Factory for creating test data.
enum TestFixtures {

    /// Creates a sample RecommendingItem for testing.
    static func makeRecommendingItem(id: String = "1",
                                      title: String = "Test Anime",
                                      anilistId: Int = 12345) -> RecommendingItem {
        RecommendingItem(id: id,
                         title: title,
                         subtitle: "Studio Name",
                         caption: "Ep. 1",
                         isCaptionHighlighted: false,
                         synopsis: "A test anime synopsis.",
                         coverURL: URL(string: "https://example.com/cover.jpg"),
                         anilistId: anilistId,
                         airDate: nil,
                         episodeNumber: 1,
                         totalEpisodes: 12)
    }

    /// Creates a sample AnimePreview for testing.
    static func makeAnimePreview(id: String = "1",
                                  title: String = "Test Anime",
                                  sourceId: String = "test-source") -> AnimePreview {
        AnimePreview(id: id,
                     title: title,
                     coverURL: nil,
                     sourceId: sourceId,
                     detailsURL: "/anime/\(id)")
    }

    /// Creates a sample Anime for testing.
    static func makeAnime(id: String = "1",
                          title: String = "Test Anime",
                          sourceId: String = "test-source") -> Anime {
        Anime(id: id,
              title: title,
              alternativeTitles: [],
              coverURL: nil,
              bannerURL: nil,
              synopsis: "A test anime for unit testing.",
              genres: ["Action", "Comedy"],
              status: .ongoing,
              year: 2024,
              rating: "PG-13",
              sourceId: sourceId,
              detailsURL: "/anime/\(id)",
              episodes: [makeEpisode()])
    }

    /// Creates a sample Episode for testing.
    static func makeEpisode(id: String = "ep1",
                            number: String = "1",
                            title: String? = "Episode Title") -> Episode {
        Episode(id: id,
                number: number,
                title: title,
                thumbnailURL: nil,
                url: "/episode/\(id)",
                duration: 1440)
    }

    /// Creates a sample SourceInfo for testing.
    static func makeSourceInfo(id: String = "test-source",
                               name: String = "Test Source") -> SourceInfo {
        SourceInfo(id: id,
                   name: name,
                   version: "1.0.0",
                   language: "en",
                   baseURL: URL(string: "https://example.com")!,
                   iconURL: nil,
                   isNSFW: false,
                   description: "A test source")
    }

    /// Creates a sample InstalledSource for testing.
    static func makeInstalledSource(id: String = "test-source",
                                     name: String = "Test Source",
                                     isEnabled: Bool = true) -> InstalledSource {
        InstalledSource(info: makeSourceInfo(id: id, name: name),
                        scriptPath: URL(fileURLWithPath: "/tmp/\(id).js"),
                        isEnabled: isEnabled,
                        installedAt: Date())
    }

    /// Creates a sample SourceRepository for testing.
    static func makeSourceRepository(name: String = "Test Repository",
                                      sources: [SourceInfo] = []) -> SourceRepository {
        SourceRepository(name: name,
                         url: URL(string: "https://example.com/repo.json")!,
                         sources: sources)
    }

    /// Creates a sample PlaybackInfo for testing.
    static func makePlaybackInfo(episodeId: String = "ep1") -> PlaybackInfo {
        PlaybackInfo(episodeId: episodeId,
                     sources: [makeVideoSource()],
                     subtitles: [])
    }

    /// Creates a sample VideoSource for testing.
    static func makeVideoSource(id: String = "source1",
                                 serverName: String = "TestServer") -> VideoSource {
        VideoSource(id: id,
                    serverName: serverName,
                    quality: "1080p",
                    url: URL(string: "https://example.com/video.m3u8")!,
                    headers: nil,
                    requiresExtraction: false)
    }

    /// Creates a sample LibraryItem for testing.
    static func makeLibraryItem(anime: AnimePreview? = nil,
                                 category: LibraryCategory = .watching) -> LibraryItem {
        LibraryItem(anime: anime ?? makeAnimePreview(),
                    category: category)
    }

    /// Creates a sample AniListAnimeDetail for testing.
    static func makeAniListAnimeDetail(id: Int = 12345,
                                        title: String = "Test Anime") -> AniListAnimeDetail {
        AniListAnimeDetail(
            id: id,
            title: title,
            romajiTitle: "Tesuto Anime",
            nativeTitle: "テストアニメ",
            englishTitle: title,
            coverURL: URL(string: "https://example.com/cover.jpg"),
            bannerURL: URL(string: "https://example.com/banner.jpg"),
            synopsis: "A test anime synopsis for testing.",
            genres: ["Action", "Comedy"],
            averageScore: 85,
            meanScore: 84,
            popularity: 10000,
            favourites: 500,
            status: .releasing,
            format: .tv,
            episodes: 12,
            duration: 24,
            season: .winter,
            seasonYear: 2026,
            startDate: AniListDate(year: 2026, month: 1, day: 1),
            endDate: nil,
            source: "MANGA",
            countryOfOrigin: "JP",
            studios: [AniListStudio(id: 1, name: "Test Studio", isAnimationStudio: true)],
            characters: [],
            relations: [],
            recommendations: [],
            externalLinks: [],
            trailer: nil,
            tags: [],
            nextAiringEpisode: nil,
            siteUrl: URL(string: "https://anilist.co/anime/12345")
        )
    }
}
