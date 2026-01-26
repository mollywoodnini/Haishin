//
//  LibraryViewModelTests.swift
//  HaishinTests
//
//  Created by Haishin on 24.01.26.
//

import Testing
import Foundation
@testable import Haishin


//#################################################################################
// MARK: - LibraryViewModel Tests
//#################################################################################

@Suite("LibraryViewModel Tests")
@MainActor
struct LibraryViewModelTests {

    //#################################################################################
    // MARK: - Mock Services
    //#################################################################################

    @MainActor
    final class MockWatchProgressService: WatchProgressServiceProtocol {
        var recentAnime: [RecentAnime] = []
        var progressMap: [String: WatchProgress] = [:]

        func getProgress(animeId: Int, episodeId: String) -> WatchProgress? {
            progressMap["\(animeId)-\(episodeId)"]
        }

        func getAllProgress(animeId: Int) -> [WatchProgress] {
            progressMap.values.filter { $0.animeId == animeId }
        }

        func saveProgress(_ progress: WatchProgress) {
            progressMap["\(progress.animeId)-\(progress.episodeId)"] = progress
        }

        func removeProgress(animeId: Int, episodeId: String) {
            progressMap.removeValue(forKey: "\(animeId)-\(episodeId)")
        }

        func clearAllProgress(animeId: Int) {
            progressMap = progressMap.filter { $0.value.animeId != animeId }
        }

        func getRecentAnime() -> [RecentAnime] {
            recentAnime
        }

        func updateRecentAnime(id: Int, title: String, coverURL: URL?, episodeNumber: String?) {
            if let index = recentAnime.firstIndex(where: { $0.id == id }) {
                recentAnime[index] = RecentAnime(id: id,
                                                 title: title,
                                                 coverURL: coverURL,
                                                 lastWatchedAt: Date(),
                                                 lastEpisodeNumber: episodeNumber)
            } else {
                recentAnime.append(RecentAnime(id: id,
                                               title: title,
                                               coverURL: coverURL,
                                               lastWatchedAt: Date(),
                                               lastEpisodeNumber: episodeNumber))
            }
        }

        func getRecentAnimeCount() -> Int {
            recentAnime.count
        }

        func removeRecentAnime(id: Int) {
            recentAnime.removeAll { $0.id == id }
        }
    }

    @MainActor
    final class MockSubscriptionService: SubscriptionServiceProtocol {
        var subscribedAnime: [SubscribedAnime] = []

        func getSubscribedAnime() -> [SubscribedAnime] {
            subscribedAnime
        }

        func subscribe(id: Int, title: String, coverURL: URL?) {
            guard !isSubscribed(id: id) else { return }
            subscribedAnime.append(SubscribedAnime(id: id,
                                                   title: title,
                                                   coverURL: coverURL,
                                                   subscribedAt: Date()))
        }

        func unsubscribe(id: Int) {
            subscribedAnime.removeAll { $0.id == id }
        }

        func isSubscribed(id: Int) -> Bool {
            subscribedAnime.contains { $0.id == id }
        }

        func getSubscribedCount() -> Int {
            subscribedAnime.count
        }
    }


    //#################################################################################
    // MARK: - Helper
    //#################################################################################

    /// Creates a fresh LibraryViewModel with mock services.
    private func makeSUT(watchProgressService: MockWatchProgressService? = nil,
                         subscriptionService: MockSubscriptionService? = nil,
                         sourceManager: MockSourceManager? = nil,
                         downloadService: MockDownloadService? = nil,
                         userPreferences: MockUserPreferences? = nil,
                         aniListService: MockAniListService? = nil) -> LibraryViewModel {
        LibraryViewModel(watchProgressService: watchProgressService ?? MockWatchProgressService(),
                         subscriptionService: subscriptionService ?? MockSubscriptionService(),
                         sourceManager: sourceManager ?? MockSourceManager(),
                         downloadService: downloadService ?? MockDownloadService(),
                         userPreferences: userPreferences ?? MockUserPreferences(),
                         aniListService: aniListService ?? MockAniListService())
    }


    //#################################################################################
    // MARK: - Initialization Tests
    //#################################################################################

    @Test("On initialization, recentAnime is loaded from service")
    func initialization_recentAnimeIsLoaded() {
        let mockWatchProgress = MockWatchProgressService()
        mockWatchProgress.recentAnime = [
            RecentAnime(id: 1,
                        title: "Test Anime",
                        coverURL: nil,
                        lastWatchedAt: Date(),
                        lastEpisodeNumber: "1")
        ]
        let sut = makeSUT(watchProgressService: mockWatchProgress)

        #expect(sut.recentAnime.count == 1)
        #expect(sut.recentAnime.first?.title == "Test Anime")
    }

    @Test("On initialization, subscribedAnime is loaded from service")
    func initialization_subscribedAnimeIsLoaded() {
        let mockSubscription = MockSubscriptionService()
        mockSubscription.subscribedAnime = [
            SubscribedAnime(id: 1,
                            title: "Subscribed Anime",
                            coverURL: nil,
                            subscribedAt: Date())
        ]
        let sut = makeSUT(subscriptionService: mockSubscription)

        #expect(sut.subscribedAnime.count == 1)
        #expect(sut.subscribedAnime.first?.title == "Subscribed Anime")
    }

    @Test("On initialization, downloadedAnime is loaded from service")
    func initialization_downloadedAnimeIsLoaded() {
        let mockDownload = MockDownloadService()
        mockDownload.downloadedAnime = [
            DownloadedAnime(id: 1,
                            title: "Downloaded Anime",
                            coverURL: nil,
                            sourceId: "test-source",
                            sourceName: "Test Source",
                            episodes: [])
        ]
        let sut = makeSUT(downloadService: mockDownload)

        #expect(sut.downloadedAnime.count == 1)
        #expect(sut.downloadedAnime.first?.title == "Downloaded Anime")
    }


    //#################################################################################
    // MARK: - recentsCount Tests
    //#################################################################################

    @Test("recentsCount returns count of recent anime")
    func recentsCount_returnsCount() {
        let mockWatchProgress = MockWatchProgressService()
        mockWatchProgress.recentAnime = [
            RecentAnime(id: 1, title: "Anime 1", coverURL: nil, lastWatchedAt: Date(), lastEpisodeNumber: nil),
            RecentAnime(id: 2, title: "Anime 2", coverURL: nil, lastWatchedAt: Date(), lastEpisodeNumber: nil)
        ]
        let sut = makeSUT(watchProgressService: mockWatchProgress)

        #expect(sut.recentsCount == 2)
    }

    @Test("recentsCount returns zero when empty")
    func recentsCount_returnsZeroWhenEmpty() {
        let sut = makeSUT()

        #expect(sut.recentsCount == 0)
    }


    //#################################################################################
    // MARK: - subscribedCount Tests
    //#################################################################################

    @Test("subscribedCount returns count of subscribed anime")
    func subscribedCount_returnsCount() {
        let mockSubscription = MockSubscriptionService()
        mockSubscription.subscribedAnime = [
            SubscribedAnime(id: 1, title: "Anime 1", coverURL: nil, subscribedAt: Date()),
            SubscribedAnime(id: 2, title: "Anime 2", coverURL: nil, subscribedAt: Date()),
            SubscribedAnime(id: 3, title: "Anime 3", coverURL: nil, subscribedAt: Date())
        ]
        let sut = makeSUT(subscriptionService: mockSubscription)

        #expect(sut.subscribedCount == 3)
    }

    @Test("subscribedCount returns zero when empty")
    func subscribedCount_returnsZeroWhenEmpty() {
        let sut = makeSUT()

        #expect(sut.subscribedCount == 0)
    }


    //#################################################################################
    // MARK: - downloadsCount Tests
    //#################################################################################

    @Test("downloadsCount returns zero (placeholder)")
    func downloadsCount_returnsZero() {
        let sut = makeSUT()

        #expect(sut.downloadsCount == 0)
    }


    //#################################################################################
    // MARK: - refresh Tests
    //#################################################################################

    @Test("refresh updates recentAnime from service")
    func refresh_updatesRecentAnime() {
        let mockWatchProgress = MockWatchProgressService()
        let sut = makeSUT(watchProgressService: mockWatchProgress)

        #expect(sut.recentAnime.isEmpty)

        // Add anime to mock service
        mockWatchProgress.recentAnime = [
            RecentAnime(id: 1, title: "New Anime", coverURL: nil, lastWatchedAt: Date(), lastEpisodeNumber: nil)
        ]

        // Refresh
        sut.refresh()

        #expect(sut.recentAnime.count == 1)
        #expect(sut.recentAnime.first?.title == "New Anime")
    }

    @Test("refresh updates subscribedAnime from service")
    func refresh_updatesSubscribedAnime() {
        let mockSubscription = MockSubscriptionService()
        let sut = makeSUT(subscriptionService: mockSubscription)

        #expect(sut.subscribedAnime.isEmpty)

        // Add anime to mock service
        mockSubscription.subscribedAnime = [
            SubscribedAnime(id: 1, title: "New Subscription", coverURL: nil, subscribedAt: Date())
        ]

        // Refresh
        sut.refresh()

        #expect(sut.subscribedAnime.count == 1)
        #expect(sut.subscribedAnime.first?.title == "New Subscription")
    }

    @Test("refresh updates downloadedAnime from service")
    func refresh_updatesDownloadedAnime() {
        let mockDownload = MockDownloadService()
        let sut = makeSUT(downloadService: mockDownload)

        #expect(sut.downloadedAnime.isEmpty)

        // Add anime to mock service
        mockDownload.downloadedAnime = [
            DownloadedAnime(id: 1,
                            title: "New Download",
                            coverURL: nil,
                            sourceId: "test-source",
                            sourceName: "Test Source",
                            episodes: [])
        ]

        // Refresh
        sut.refresh()

        #expect(sut.downloadedAnime.count == 1)
        #expect(sut.downloadedAnime.first?.title == "New Download")
    }


    //#################################################################################
    // MARK: - removeAllDownloads Tests
    //#################################################################################

    @Test("removeAllDownloads removes anime from downloadedAnime")
    func removeAllDownloads_removesAnimeFromList() {
        let mockDownload = MockDownloadService()
        mockDownload.downloadedAnime = [
            DownloadedAnime(id: 1,
                            title: "Anime 1",
                            coverURL: nil,
                            sourceId: "test-source",
                            sourceName: "Test Source",
                            episodes: []),
            DownloadedAnime(id: 2,
                            title: "Anime 2",
                            coverURL: nil,
                            sourceId: "test-source",
                            sourceName: "Test Source",
                            episodes: [])
        ]
        let sut = makeSUT(downloadService: mockDownload)

        #expect(sut.downloadedAnime.count == 2)

        sut.removeAllDownloads(forAnimeId: 1)

        #expect(sut.downloadedAnime.count == 1)
        #expect(sut.downloadedAnime.first?.id == 2)
    }

    @Test("removeAllDownloads calls download service")
    func removeAllDownloads_callsDownloadService() {
        let mockDownload = MockDownloadService()
        mockDownload.downloadedAnime = [
            DownloadedAnime(id: 1,
                            title: "Anime 1",
                            coverURL: nil,
                            sourceId: "test-source",
                            sourceName: "Test Source",
                            episodes: [])
        ]
        let sut = makeSUT(downloadService: mockDownload)

        sut.removeAllDownloads(forAnimeId: 1)

        // Verify service was called (mock removes from its own list)
        #expect(mockDownload.downloadedAnime.isEmpty)
    }
}
