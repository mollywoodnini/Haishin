//
//  LibraryViewModelTests.swift
//  HaishinTests
//
//  Created by Tan Nghia La on 24.01.26.
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
        var recentVideo: [RecentVideo] = []
        var progressMap: [String: WatchProgress] = [:]

        func getProgress(videoId: String, episodeId: String) -> WatchProgress? {
            progressMap["\(videoId)-\(episodeId)"]
        }

        func getAllProgress(videoId: String) -> [WatchProgress] {
            progressMap.values.filter { $0.videoId == videoId }
        }

        func saveProgress(_ progress: WatchProgress) {
            progressMap["\(progress.videoId)-\(progress.episodeId)"] = progress
        }

        func removeProgress(videoId: String, episodeId: String) {
            progressMap.removeValue(forKey: "\(videoId)-\(episodeId)")
        }

        func clearAllProgress(videoId: String) {
            progressMap = progressMap.filter { $0.value.videoId != videoId }
        }

        func getRecentVideo() -> [RecentVideo] {
            recentVideo
        }

        func updateRecentVideo(id: String,
                               title: String,
                               coverURL: URL?,
                               sourceId: String,
                               detailsURL: String?,
                               episodeNumber: String?) {
            if let index = recentVideo.firstIndex(where: { $0.id == id }) {
                recentVideo[index] = RecentVideo(id: id,
                                                 title: title,
                                                 coverURL: coverURL,
                                                 sourceId: sourceId,
                                                 detailsURL: detailsURL,
                                                 lastWatchedAt: Date(),
                                                 lastEpisodeNumber: episodeNumber)
            } else {
                recentVideo.append(RecentVideo(id: id,
                                               title: title,
                                               coverURL: coverURL,
                                               sourceId: sourceId,
                                               detailsURL: detailsURL,
                                               lastWatchedAt: Date(),
                                               lastEpisodeNumber: episodeNumber))
            }
        }

        func getRecentVideoCount() -> Int {
            recentVideo.count
        }

        func removeRecentVideo(id: String) {
            recentVideo.removeAll { $0.id == id }
        }
    }

    @MainActor
    final class MockSubscriptionService: SubscriptionServiceProtocol {
        var subscribedVideo: [SubscribedVideo] = []

        func getSubscribedVideo() -> [SubscribedVideo] {
            subscribedVideo
        }

        func getSubscribedCount() -> Int {
            subscribedVideo.count
        }

        var subscribedAnimeList: [SubscribedAnime] = []

        func getSubscribedAnime() -> [SubscribedAnime] {
            subscribedAnimeList
        }

        func subscribeAnime(id: Int, title: String, coverURL: URL?) {
            guard !isAnimeSubscribed(id: id) else { return }
            subscribedAnimeList.append(SubscribedAnime(id: id, title: title, coverURL: coverURL, subscribedAt: Date()))
        }

        func unsubscribeAnime(id: Int) {
            subscribedAnimeList.removeAll { $0.id == id }
        }

        func isAnimeSubscribed(id: Int) -> Bool {
            subscribedAnimeList.contains { $0.id == id }
        }

        func getSubscribedAnimeCount() -> Int {
            subscribedAnimeList.count
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
                         userPreferences: MockUserPreferences? = nil) -> LibraryViewModel {
        LibraryViewModel(watchProgressService: watchProgressService ?? MockWatchProgressService(),
                         subscriptionService: subscriptionService ?? MockSubscriptionService(),
                         sourceManager: sourceManager ?? MockSourceManager(),
                         downloadService: downloadService ?? MockDownloadService(),
                         userPreferences: userPreferences ?? MockUserPreferences())
    }


    //#################################################################################
    // MARK: - Initialization Tests
    //#################################################################################

    @Test("On initialization, recentVideo is loaded from service")
    func initialization_recentVideoIsLoaded() {
        let mockWatchProgress = MockWatchProgressService()
        mockWatchProgress.recentVideo = [
            RecentVideo(id: "1",
                        title: "Test Video",
                        coverURL: nil,
                        sourceId: "test-source",
                        detailsURL: nil,
                        lastWatchedAt: Date(),
                        lastEpisodeNumber: "1")
        ]
        let sut = makeSUT(watchProgressService: mockWatchProgress)

        #expect(sut.recentVideo.count == 1)
        #expect(sut.recentVideo.first?.title == "Test Video")
    }

    @Test("On initialization, subscribedVideo is loaded from service")
    func initialization_subscribedVideoIsLoaded() {
        let mockSubscription = MockSubscriptionService()
        mockSubscription.subscribedVideo = [
            SubscribedVideo(id: "1",
                            title: "Subscribed Video",
                            coverURL: nil,
                            sourceId: "test-source",
                            detailsURL: nil,
                            subscribedAt: Date())
        ]
        let sut = makeSUT(subscriptionService: mockSubscription)

        #expect(sut.subscribedVideo.count == 1)
        #expect(sut.subscribedVideo.first?.title == "Subscribed Video")
    }

    @Test("On initialization, downloadedVideo is loaded from service")
    func initialization_downloadedVideoIsLoaded() {
        let mockDownload = MockDownloadService()
        mockDownload.downloadedVideo = [
            DownloadedVideo(id: "1",
                            title: "Downloaded Video",
                            coverURL: nil,
                            sourceId: "test-source",
                            detailsURL: nil,
                            sourceName: "Test Source",
                            episodes: [])
        ]
        let sut = makeSUT(downloadService: mockDownload)

        #expect(sut.downloadedVideo.count == 1)
        #expect(sut.downloadedVideo.first?.title == "Downloaded Video")
    }


    //#################################################################################
    // MARK: - recentsCount Tests
    //#################################################################################

    @Test("recentsCount returns count of recent videos")
    func recentsCount_returnsCount() {
        let mockWatchProgress = MockWatchProgressService()
        mockWatchProgress.recentVideo = [
            RecentVideo(id: "1", title: "Video 1", coverURL: nil, sourceId: "test-source",
                        detailsURL: nil, lastWatchedAt: Date(), lastEpisodeNumber: nil),
            RecentVideo(id: "2", title: "Video 2", coverURL: nil, sourceId: "test-source",
                        detailsURL: nil, lastWatchedAt: Date(), lastEpisodeNumber: nil)
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

    @Test("subscribedCount returns count of subscribed videos")
    func subscribedCount_returnsCount() {
        let mockSubscription = MockSubscriptionService()
        mockSubscription.subscribedVideo = [
            SubscribedVideo(id: "1", title: "Video 1", coverURL: nil, sourceId: "test-source",
                            detailsURL: nil, subscribedAt: Date()),
            SubscribedVideo(id: "2", title: "Video 2", coverURL: nil, sourceId: "test-source",
                            detailsURL: nil, subscribedAt: Date()),
            SubscribedVideo(id: "3", title: "Video 3", coverURL: nil, sourceId: "test-source",
                            detailsURL: nil, subscribedAt: Date())
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

    @Test("refresh updates recentVideo from service")
    func refresh_updatesRecentVideo() {
        let mockWatchProgress = MockWatchProgressService()
        let sut = makeSUT(watchProgressService: mockWatchProgress)

        #expect(sut.recentVideo.isEmpty)

        // Add video to mock service
        mockWatchProgress.recentVideo = [
            RecentVideo(id: "1", title: "New Video", coverURL: nil, sourceId: "test-source",
                        detailsURL: nil, lastWatchedAt: Date(), lastEpisodeNumber: nil)
        ]

        // Refresh
        sut.refresh()

        #expect(sut.recentVideo.count == 1)
        #expect(sut.recentVideo.first?.title == "New Video")
    }

    @Test("refresh updates subscribedVideo from service")
    func refresh_updatesSubscribedVideo() {
        let mockSubscription = MockSubscriptionService()
        let sut = makeSUT(subscriptionService: mockSubscription)

        #expect(sut.subscribedVideo.isEmpty)

        // Add video to mock service
        mockSubscription.subscribedVideo = [
            SubscribedVideo(id: "1", title: "New Subscription", coverURL: nil, sourceId: "test-source",
                            detailsURL: nil, subscribedAt: Date())
        ]

        // Refresh
        sut.refresh()

        #expect(sut.subscribedVideo.count == 1)
        #expect(sut.subscribedVideo.first?.title == "New Subscription")
    }

    @Test("refresh updates downloadedVideo from service")
    func refresh_updatesDownloadedVideo() {
        let mockDownload = MockDownloadService()
        let sut = makeSUT(downloadService: mockDownload)

        #expect(sut.downloadedVideo.isEmpty)

        // Add video to mock service
        mockDownload.downloadedVideo = [
            DownloadedVideo(id: "1",
                            title: "New Download",
                            coverURL: nil,
                            sourceId: "test-source",
                            detailsURL: nil,
                            sourceName: "Test Source",
                            episodes: [])
        ]

        // Refresh
        sut.refresh()

        #expect(sut.downloadedVideo.count == 1)
        #expect(sut.downloadedVideo.first?.title == "New Download")
    }


    //#################################################################################
    // MARK: - removeAllDownloads Tests
    //#################################################################################

    @Test("removeAllDownloads removes video from downloadedVideo")
    func removeAllDownloads_removesVideoFromList() {
        let mockDownload = MockDownloadService()
        mockDownload.downloadedVideo = [
            DownloadedVideo(id: "1",
                            title: "Video 1",
                            coverURL: nil,
                            sourceId: "test-source",
                            detailsURL: nil,
                            sourceName: "Test Source",
                            episodes: []),
            DownloadedVideo(id: "2",
                            title: "Video 2",
                            coverURL: nil,
                            sourceId: "test-source",
                            detailsURL: nil,
                            sourceName: "Test Source",
                            episodes: [])
        ]
        let sut = makeSUT(downloadService: mockDownload)

        #expect(sut.downloadedVideo.count == 2)

        sut.removeAllDownloads(forVideoId: "1")

        #expect(sut.downloadedVideo.count == 1)
        #expect(sut.downloadedVideo.first?.id == "2")
    }

    @Test("removeAllDownloads calls download service")
    func removeAllDownloads_callsDownloadService() {
        let mockDownload = MockDownloadService()
        mockDownload.downloadedVideo = [
            DownloadedVideo(id: "1",
                            title: "Video 1",
                            coverURL: nil,
                            sourceId: "test-source",
                            detailsURL: nil,
                            sourceName: "Test Source",
                            episodes: [])
        ]
        let sut = makeSUT(downloadService: mockDownload)

        sut.removeAllDownloads(forVideoId: "1")

        // Verify service was called (mock removes from its own list)
        #expect(mockDownload.downloadedVideo.isEmpty)
    }
}
