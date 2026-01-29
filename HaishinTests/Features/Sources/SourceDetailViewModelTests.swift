//
//  SourceDetailViewModelTests.swift
//  HaishinTests
//
//  Created by Claude on 29.01.26.
//

import Testing
import Foundation
@testable import Haishin


//#################################################################################
// MARK: - SourceDetailViewModel Tests
//#################################################################################

@Suite("SourceDetailViewModel Tests")
@MainActor
struct SourceDetailViewModelTests {

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
                               episodeNumber: String?) {
            if let index = recentVideo.firstIndex(where: { $0.id == id }) {
                recentVideo[index] = RecentVideo(id: id,
                                                 title: title,
                                                 coverURL: coverURL,
                                                 sourceId: sourceId,
                                                 lastWatchedAt: Date(),
                                                 lastEpisodeNumber: episodeNumber)
            } else {
                recentVideo.append(RecentVideo(id: id,
                                               title: title,
                                               coverURL: coverURL,
                                               sourceId: sourceId,
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

        func subscribe(id: String, title: String, coverURL: URL?, sourceId: String) {
            guard !isSubscribed(id: id) else { return }
            subscribedVideo.append(SubscribedVideo(id: id,
                                                   title: title,
                                                   coverURL: coverURL,
                                                   sourceId: sourceId,
                                                   subscribedAt: Date()))
        }

        func unsubscribe(id: String) {
            subscribedVideo.removeAll { $0.id == id }
        }

        func isSubscribed(id: String) -> Bool {
            subscribedVideo.contains { $0.id == id }
        }

        func getSubscribedCount() -> Int {
            subscribedVideo.count
        }
    }


    //#################################################################################
    // MARK: - Helper
    //#################################################################################

    private func makeSUT(source: InstalledSource? = nil,
                         sourceManager: MockSourceManager? = nil,
                         watchProgressService: MockWatchProgressService? = nil,
                         subscriptionService: MockSubscriptionService? = nil,
                         downloadService: MockDownloadService? = nil) -> SourceDetailViewModel {
        SourceDetailViewModel(source: source ?? TestFixtures.makeInstalledSource(),
                              sourceManager: sourceManager ?? MockSourceManager(),
                              watchProgressService: watchProgressService ?? MockWatchProgressService(),
                              subscriptionService: subscriptionService ?? MockSubscriptionService(),
                              downloadService: downloadService ?? MockDownloadService())
    }


    //#################################################################################
    // MARK: - Initialization Tests
    //#################################################################################

    @Test("On initialization, source is set correctly")
    func initialization_sourceIsSet() {
        let source = TestFixtures.makeInstalledSource(id: "test-id", name: "Test Name")
        let sut = makeSUT(source: source)

        #expect(sut.source.id == "test-id")
        #expect(sut.source.info.name == "Test Name")
    }

    @Test("On initialization, videos is empty")
    func initialization_videosIsEmpty() {
        let sut = makeSUT()

        #expect(sut.videos.isEmpty)
    }

    @Test("On initialization, isLoading is false")
    func initialization_isLoadingIsFalse() {
        let sut = makeSUT()

        #expect(sut.isLoading == false)
    }

    @Test("On initialization, error is nil")
    func initialization_errorIsNil() {
        let sut = makeSUT()

        #expect(sut.error == nil)
    }

    @Test("On initialization, hasLoadedContent is false")
    func initialization_hasLoadedContentIsFalse() {
        let sut = makeSUT()

        #expect(sut.hasLoadedContent == false)
    }


    //#################################################################################
    // MARK: - loadContent Tests
    //#################################################################################

    @Test("loadContent calls source manager getEntryVideos")
    func loadContent_callsSourceManager() async {
        let mockSourceManager = MockSourceManager()
        let sut = makeSUT(sourceManager: mockSourceManager)

        await sut.loadContent()

        #expect(mockSourceManager.getEntryVideosCallCount == 1)
    }

    @Test("loadContent with success populates videos")
    func loadContent_withSuccess_populatesVideos() async {
        let mockSourceManager = MockSourceManager()
        let videos = [
            TestFixtures.makeVideoPreview(id: "1", title: "Video 1"),
            TestFixtures.makeVideoPreview(id: "2", title: "Video 2")
        ]
        mockSourceManager.getEntryVideosResult = .success(videos)
        let sut = makeSUT(sourceManager: mockSourceManager)

        await sut.loadContent()

        #expect(sut.videos.count == 2)
        #expect(sut.videos[0].id == "1")
        #expect(sut.videos[1].id == "2")
    }

    @Test("loadContent with success clears error")
    func loadContent_withSuccess_clearsError() async {
        let mockSourceManager = MockSourceManager()
        mockSourceManager.getEntryVideosResult = .success([])
        let sut = makeSUT(sourceManager: mockSourceManager)

        await sut.loadContent()

        #expect(sut.error == nil)
    }

    @Test("loadContent with failure sets error")
    func loadContent_withFailure_setsError() async {
        let mockSourceManager = MockSourceManager()
        mockSourceManager.getEntryVideosResult = .failure(MockError.testError)
        let sut = makeSUT(sourceManager: mockSourceManager)

        await sut.loadContent()

        #expect(sut.error != nil)
    }

    @Test("loadContent with failure keeps videos empty")
    func loadContent_withFailure_keepsVideosEmpty() async {
        let mockSourceManager = MockSourceManager()
        mockSourceManager.getEntryVideosResult = .failure(MockError.testError)
        let sut = makeSUT(sourceManager: mockSourceManager)

        await sut.loadContent()

        #expect(sut.videos.isEmpty)
    }

    @Test("loadContent sets isLoading to false when complete")
    func loadContent_setsIsLoadingToFalseWhenComplete() async {
        let mockSourceManager = MockSourceManager()
        let sut = makeSUT(sourceManager: mockSourceManager)

        await sut.loadContent()

        #expect(sut.isLoading == false)
    }

    @Test("loadContent sets hasLoadedContent to true")
    func loadContent_setsHasLoadedContentToTrue() async {
        let mockSourceManager = MockSourceManager()
        let sut = makeSUT(sourceManager: mockSourceManager)

        await sut.loadContent()

        #expect(sut.hasLoadedContent == true)
    }

    @Test("loadContent skips loading when already loaded")
    func loadContent_skipsLoadingWhenAlreadyLoaded() async {
        let mockSourceManager = MockSourceManager()
        let sut = makeSUT(sourceManager: mockSourceManager)

        await sut.loadContent()
        await sut.loadContent()

        #expect(mockSourceManager.getEntryVideosCallCount == 1)
    }

    @Test("loadContent with forceRefresh reloads even when already loaded")
    func loadContent_withForceRefresh_reloadsEvenWhenAlreadyLoaded() async {
        let mockSourceManager = MockSourceManager()
        let sut = makeSUT(sourceManager: mockSourceManager)

        await sut.loadContent()
        await sut.loadContent(forceRefresh: true)

        #expect(mockSourceManager.getEntryVideosCallCount == 2)
    }


    //#################################################################################
    // MARK: - makeEpisodeListViewModel Tests
    //#################################################################################

    @Test("makeEpisodeListViewModel creates ViewModel with correct video")
    func makeEpisodeListViewModel_createsViewModelWithCorrectVideo() {
        let sut = makeSUT()
        let videoPreview = TestFixtures.makeVideoPreview(id: "test-video", title: "Test Title")

        let episodeListViewModel = sut.makeEpisodeListViewModel(for: videoPreview)

        #expect(episodeListViewModel.videoTitle == "Test Title")
    }

    @Test("makeEpisodeListViewModel creates ViewModel with correct videoId")
    func makeEpisodeListViewModel_createsViewModelWithCorrectVideoId() {
        let sut = makeSUT()
        let videoPreview = TestFixtures.makeVideoPreview(id: "test-video-123")

        let episodeListViewModel = sut.makeEpisodeListViewModel(for: videoPreview)

        #expect(episodeListViewModel.videoId == "test-video-123")
    }
}
