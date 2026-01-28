//
//  MockSourceManager.swift
//  HaishinTests
//
//  Created by Haishin on 24.01.26.
//

import Foundation
@testable import Haishin

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

    func installSource(fromURL urlString: String) async throws {
        installSourceCallCount += 1
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
// MARK: - MockUserPreferences
//#################################################################################

/// Mock implementation of UserPreferencesProtocol for testing.
@MainActor
final class MockUserPreferences: UserPreferencesProtocol {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    var appearance: AppearanceMode = .system


    //#################################################################################
    // MARK: - Call Tracking
    //#################################################################################

    var clearAllCallCount = 0


    //#################################################################################
    // MARK: - Methods
    //#################################################################################

    func clearAll() {
        clearAllCallCount += 1
        appearance = .system
    }
}


//#################################################################################
// MARK: - MockDownloadService
//#################################################################################

/// Mock implementation of DownloadServiceProtocol for testing.
@MainActor
final class MockDownloadService: DownloadServiceProtocol {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    var downloadedAnime: [DownloadedAnime] = []
    var activeDownloads: [DownloadedEpisode] = []
    var totalDownloadsCount: Int { downloadedAnime.flatMap(\.episodes).count }


    //#################################################################################
    // MARK: - Call Tracking
    //#################################################################################

    var setSourceManagerCallCount = 0
    var startDownloadCallCount = 0
    var cancelDownloadCallCount = 0
    var removeDownloadCallCount = 0


    //#################################################################################
    // MARK: - Methods
    //#################################################################################

    func setSourceManager(_ sourceManager: SourceManaging) {
        setSourceManagerCallCount += 1
    }

    func startDownload(animeId: String,
                       animeTitle: String,
                       animeCoverURL: URL?,
                       episodeId: String,
                       episodeNumber: String,
                       episodeTitle: String?,
                       sourceId: String,
                       sourceName: String,
                       sourceURL: String) {
        startDownloadCallCount += 1
    }

    func cancelDownload(episodeId: String) {
        cancelDownloadCallCount += 1
    }

    func removeDownload(episodeId: String) {
        removeDownloadCallCount += 1
    }

    func getDownloadState(episodeId: String) -> DownloadState? {
        nil
    }

    func getDownloads(forAnimeId animeId: String) -> [DownloadedEpisode] {
        downloadedAnime.first { $0.id == animeId }?.episodes ?? []
    }

    func removeAllDownloads(forAnimeId animeId: String) {
        downloadedAnime.removeAll { $0.id == animeId }
    }
}


//#################################################################################
// MARK: - Test Fixtures
//#################################################################################

/// Factory for creating test data.
enum TestFixtures {

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
        let episode = makeEpisode()
        let episodeRange = EpisodeRange(id: "range-1",
                                        title: "1 - 1",
                                        episodes: [episode])
        return Anime(id: id,
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
                     episodes: [episode],
                     episodeRanges: [episodeRange])
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
                                     name: String = "Test Source") -> InstalledSource {
        InstalledSource(info: makeSourceInfo(id: id, name: name),
                        scriptPath: URL(fileURLWithPath: "/tmp/\(id).js"),
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
}
