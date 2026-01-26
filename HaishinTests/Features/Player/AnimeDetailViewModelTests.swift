//
//  AnimeDetailViewModelTests.swift
//  HaishinTests
//
//  Created by Haishin on 24.01.26.
//

import Foundation
import Testing
@testable import Haishin


//#################################################################################
// MARK: - AnimeDetailViewModel Tests
//#################################################################################

@Suite("AnimeDetailViewModel Tests")
@MainActor
struct AnimeDetailViewModelTests {

    //#################################################################################
    // MARK: - Mocks
    //#################################################################################

    @MainActor
    final class MockSubscriptionService: SubscriptionServiceProtocol {
        var subscribedAnime: [SubscribedAnime] = []
        var subscribeCallCount = 0
        var unsubscribeCallCount = 0

        func getSubscribedAnime() -> [SubscribedAnime] {
            subscribedAnime
        }

        func subscribe(id: Int, title: String, coverURL: URL?) {
            subscribeCallCount += 1
            guard !isSubscribed(id: id) else { return }
            subscribedAnime.append(SubscribedAnime(id: id,
                                                   title: title,
                                                   coverURL: coverURL,
                                                   subscribedAt: Date()))
        }

        func unsubscribe(id: Int) {
            unsubscribeCallCount += 1
            subscribedAnime.removeAll { $0.id == id }
        }

        func isSubscribed(id: Int) -> Bool {
            subscribedAnime.contains { $0.id == id }
        }

        func getSubscribedCount() -> Int {
            subscribedAnime.count
        }
    }

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


    //#################################################################################
    // MARK: - Helper Methods
    //#################################################################################

    private func makeSUT(item: RecommendingItem? = nil,
                         aniListService: MockAniListService? = nil,
                         subscriptionService: MockSubscriptionService? = nil,
                         watchProgressService: MockWatchProgressService? = nil,
                         sourceManager: MockSourceManager? = nil,
                         userPreferences: MockUserPreferences? = nil) -> AnimeDetailViewModel {
        AnimeDetailViewModel(mode: .item(item ?? TestFixtures.makeRecommendingItem()),
                             aniListService: aniListService ?? MockAniListService(),
                             subscriptionService: subscriptionService ?? MockSubscriptionService(),
                             watchProgressService: watchProgressService ?? MockWatchProgressService(),
                             sourceManager: sourceManager ?? MockSourceManager(),
                             userPreferences: userPreferences ?? MockUserPreferences())
    }


    //#################################################################################
    // MARK: - Initialization Tests
    //#################################################################################

    @Test("On initialization, animeId is set")
    func initialization_animeIdIsSet() {
        let item = TestFixtures.makeRecommendingItem(anilistId: 12345)
        let sut = makeSUT(item: item)

        #expect(sut.animeId == 12345)
    }

    @Test("On initialization, previewTitle is set")
    func initialization_previewTitleIsSet() {
        let item = TestFixtures.makeRecommendingItem(title: "Test Anime Title")
        let sut = makeSUT(item: item)

        #expect(sut.previewTitle == "Test Anime Title")
    }

    @Test("On initialization, previewCoverURL is set")
    func initialization_previewCoverURLIsSet() {
        let item = TestFixtures.makeRecommendingItem()
        let sut = makeSUT(item: item)

        #expect(sut.previewCoverURL != nil)
    }

    @Test("On initialization, anime is nil")
    func initialization_animeIsNil() {
        let sut = makeSUT()

        #expect(sut.anime == nil)
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

    @Test("On initialization, isSynopsisExpanded is false")
    func initialization_isSynopsisExpandedIsFalse() {
        let sut = makeSUT()

        #expect(sut.isSynopsisExpanded == false)
    }

    @Test("On initialization, isSubscribed reflects subscriptionService state")
    func initialization_isSubscribedReflectsServiceState() {
        let mockSubscriptionService = MockSubscriptionService()
        let item = TestFixtures.makeRecommendingItem(anilistId: 12345)

        // Not subscribed initially
        let sut1 = makeSUT(item: item, subscriptionService: mockSubscriptionService)
        #expect(sut1.isSubscribed == false)

        // Now subscribe and create new viewmodel
        mockSubscriptionService.subscribe(id: 12345, title: "Test", coverURL: nil)
        let sut2 = makeSUT(item: item, subscriptionService: mockSubscriptionService)
        #expect(sut2.isSubscribed == true)
    }


    //#################################################################################
    // MARK: - loadDetails Tests
    //#################################################################################

    @Test("loadDetails calls AniList service")
    func loadDetails_callsAniListService() async {
        let mockAniListService = MockAniListService()
        let item = TestFixtures.makeRecommendingItem(anilistId: 12345)
        let sut = makeSUT(item: item, aniListService: mockAniListService)

        // Given
        let anime = TestFixtures.makeAniListAnimeDetail()
        mockAniListService.fetchAnimeDetailsResult = .success(anime)

        // When
        await sut.loadDetails()

        // Then
        #expect(mockAniListService.fetchAnimeDetailsCallCount == 1)
        #expect(mockAniListService.fetchAnimeDetailsIds.first == 12345)
    }

    @Test("loadDetails on success sets anime")
    func loadDetails_onSuccess_setsAnime() async {
        let mockAniListService = MockAniListService()
        let sut = makeSUT(aniListService: mockAniListService)

        // Given
        let anime = TestFixtures.makeAniListAnimeDetail(title: "Loaded Anime")
        mockAniListService.fetchAnimeDetailsResult = .success(anime)

        // When
        await sut.loadDetails()

        // Then
        #expect(sut.anime != nil)
        #expect(sut.anime?.title == "Loaded Anime")
    }

    @Test("loadDetails on error sets error")
    func loadDetails_onError_setsError() async {
        let mockAniListService = MockAniListService()
        let sut = makeSUT(aniListService: mockAniListService)

        // Given
        mockAniListService.fetchAnimeDetailsResult = .failure(MockError.testError)

        // When
        await sut.loadDetails()

        // Then
        #expect(sut.anime == nil)
        #expect(sut.error != nil)
    }

    @Test("loadDetails on success sets isLoading to false")
    func loadDetails_onSuccess_setsIsLoadingToFalse() async {
        let mockAniListService = MockAniListService()
        let sut = makeSUT(aniListService: mockAniListService)

        // Given
        let anime = TestFixtures.makeAniListAnimeDetail()
        mockAniListService.fetchAnimeDetailsResult = .success(anime)

        // When
        await sut.loadDetails()

        // Then
        #expect(sut.isLoading == false)
    }

    @Test("loadDetails on error sets isLoading to false")
    func loadDetails_onError_setsIsLoadingToFalse() async {
        let mockAniListService = MockAniListService()
        let sut = makeSUT(aniListService: mockAniListService)

        // Given
        mockAniListService.fetchAnimeDetailsResult = .failure(MockError.testError)

        // When
        await sut.loadDetails()

        // Then
        #expect(sut.isLoading == false)
    }

    @Test("loadDetails when already loaded does not load again")
    func loadDetails_whenAlreadyLoaded_doesNotLoadAgain() async {
        let mockAniListService = MockAniListService()
        let sut = makeSUT(aniListService: mockAniListService)

        // Given
        let anime = TestFixtures.makeAniListAnimeDetail()
        mockAniListService.fetchAnimeDetailsResult = .success(anime)

        // Load once
        await sut.loadDetails()
        #expect(mockAniListService.fetchAnimeDetailsCallCount == 1)

        // When - Try to load again
        await sut.loadDetails()

        // Then - Should not load again
        #expect(mockAniListService.fetchAnimeDetailsCallCount == 1)
    }

    @Test("loadDetails when already loading does not load again")
    func loadDetails_whenAlreadyLoading_doesNotLoadAgain() async {
        let mockAniListService = MockAniListService()
        let sut = makeSUT(aniListService: mockAniListService)

        // Given
        let anime = TestFixtures.makeAniListAnimeDetail()
        mockAniListService.fetchAnimeDetailsResult = .success(anime)

        // When - Start multiple loads concurrently
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await sut.loadDetails()
            }
            group.addTask {
                await sut.loadDetails()
            }
        }

        // Then - Should only load once due to guard
        #expect(mockAniListService.fetchAnimeDetailsCallCount == 1)
    }


    //#################################################################################
    // MARK: - retry Tests
    //#################################################################################

    @Test("retry resets error and reloads")
    func retry_resetsErrorAndReloads() async {
        let mockAniListService = MockAniListService()
        let sut = makeSUT(aniListService: mockAniListService)

        // Given - First load fails
        mockAniListService.fetchAnimeDetailsResult = .failure(MockError.testError)
        await sut.loadDetails()
        #expect(sut.error != nil)
        #expect(mockAniListService.fetchAnimeDetailsCallCount == 1)

        // When - Retry with success
        let anime = TestFixtures.makeAniListAnimeDetail()
        mockAniListService.fetchAnimeDetailsResult = .success(anime)
        await sut.retry()

        // Then
        #expect(sut.error == nil)
        #expect(sut.anime != nil)
        #expect(mockAniListService.fetchAnimeDetailsCallCount == 2)
    }


    //#################################################################################
    // MARK: - Computed Properties Tests
    //#################################################################################

    @Test("displayTitle returns previewTitle when anime is nil")
    func displayTitle_returnsPreviewTitleWhenAnimeIsNil() {
        let item = TestFixtures.makeRecommendingItem(title: "Preview Title")
        let sut = makeSUT(item: item)

        #expect(sut.displayTitle == "Preview Title")
    }

    @Test("displayTitle returns anime title when loaded")
    func displayTitle_returnsAnimeTitleWhenLoaded() async {
        let mockAniListService = MockAniListService()
        let item = TestFixtures.makeRecommendingItem(title: "Preview Title")
        let sut = makeSUT(item: item, aniListService: mockAniListService)

        // Given
        let anime = TestFixtures.makeAniListAnimeDetail(title: "Loaded Title")
        mockAniListService.fetchAnimeDetailsResult = .success(anime)

        // When
        await sut.loadDetails()

        // Then
        #expect(sut.displayTitle == "Loaded Title")
    }

    @Test("displayCoverURL returns previewCoverURL when anime is nil")
    func displayCoverURL_returnsPreviewCoverURLWhenAnimeIsNil() {
        let item = TestFixtures.makeRecommendingItem()
        let sut = makeSUT(item: item)

        #expect(sut.displayCoverURL == item.coverURL)
    }

    @Test("displayCoverURL returns anime coverURL when loaded")
    func displayCoverURL_returnsAnimeCoverURLWhenLoaded() async {
        let mockAniListService = MockAniListService()
        let sut = makeSUT(aniListService: mockAniListService)

        // Given
        let anime = TestFixtures.makeAniListAnimeDetail()
        mockAniListService.fetchAnimeDetailsResult = .success(anime)

        // When
        await sut.loadDetails()

        // Then
        #expect(sut.displayCoverURL == anime.coverURL)
    }


    //#################################################################################
    // MARK: - toggleSubscription Tests
    //#################################################################################

    @Test("toggleSubscription subscribes when not subscribed")
    func toggleSubscription_subscribesWhenNotSubscribed() {
        let mockSubscriptionService = MockSubscriptionService()
        let item = TestFixtures.makeRecommendingItem(anilistId: 12345)
        let sut = makeSUT(item: item, subscriptionService: mockSubscriptionService)

        // Given
        #expect(sut.isSubscribed == false)

        // When
        sut.toggleSubscription()

        // Then
        #expect(sut.isSubscribed == true)
        #expect(mockSubscriptionService.subscribeCallCount == 1)
        #expect(mockSubscriptionService.isSubscribed(id: 12345) == true)
    }

    @Test("toggleSubscription unsubscribes when subscribed")
    func toggleSubscription_unsubscribesWhenSubscribed() {
        let mockSubscriptionService = MockSubscriptionService()
        let item = TestFixtures.makeRecommendingItem(anilistId: 12345)

        // Subscribe first
        mockSubscriptionService.subscribe(id: 12345, title: "Test", coverURL: nil)

        let sut = makeSUT(item: item, subscriptionService: mockSubscriptionService)

        // Given
        #expect(sut.isSubscribed == true)

        // When
        sut.toggleSubscription()

        // Then
        #expect(sut.isSubscribed == false)
        #expect(mockSubscriptionService.unsubscribeCallCount == 1)
        #expect(mockSubscriptionService.isSubscribed(id: 12345) == false)
    }
}
