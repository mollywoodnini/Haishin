//
//  AnimeDetailViewModelTests.swift
//  HaishinTests
//
//  Created by Haishin on 24.01.26.
//

import Testing
@testable import Haishin


//#################################################################################
// MARK: - AnimeDetailViewModel Tests
//#################################################################################

@Suite("AnimeDetailViewModel Tests")
@MainActor
struct AnimeDetailViewModelTests {

    //#################################################################################
    // MARK: - Initialization Tests
    //#################################################################################

    @Test("On initialization, animeId is set")
    func initialization_animeIdIsSet() {
        let mockAniListService = MockAniListService()
        let item = TestFixtures.makeRecommendingItem(anilistId: 12345)
        let sut = AnimeDetailViewModel(item: item, aniListService: mockAniListService)

        #expect(sut.animeId == 12345)
    }

    @Test("On initialization, previewTitle is set")
    func initialization_previewTitleIsSet() {
        let mockAniListService = MockAniListService()
        let item = TestFixtures.makeRecommendingItem(title: "Test Anime Title")
        let sut = AnimeDetailViewModel(item: item, aniListService: mockAniListService)

        #expect(sut.previewTitle == "Test Anime Title")
    }

    @Test("On initialization, previewCoverURL is set")
    func initialization_previewCoverURLIsSet() {
        let mockAniListService = MockAniListService()
        let item = TestFixtures.makeRecommendingItem()
        let sut = AnimeDetailViewModel(item: item, aniListService: mockAniListService)

        #expect(sut.previewCoverURL != nil)
    }

    @Test("On initialization, anime is nil")
    func initialization_animeIsNil() {
        let mockAniListService = MockAniListService()
        let item = TestFixtures.makeRecommendingItem()
        let sut = AnimeDetailViewModel(item: item, aniListService: mockAniListService)

        #expect(sut.anime == nil)
    }

    @Test("On initialization, isLoading is false")
    func initialization_isLoadingIsFalse() {
        let mockAniListService = MockAniListService()
        let item = TestFixtures.makeRecommendingItem()
        let sut = AnimeDetailViewModel(item: item, aniListService: mockAniListService)

        #expect(sut.isLoading == false)
    }

    @Test("On initialization, error is nil")
    func initialization_errorIsNil() {
        let mockAniListService = MockAniListService()
        let item = TestFixtures.makeRecommendingItem()
        let sut = AnimeDetailViewModel(item: item, aniListService: mockAniListService)

        #expect(sut.error == nil)
    }

    @Test("On initialization, isSynopsisExpanded is false")
    func initialization_isSynopsisExpandedIsFalse() {
        let mockAniListService = MockAniListService()
        let item = TestFixtures.makeRecommendingItem()
        let sut = AnimeDetailViewModel(item: item, aniListService: mockAniListService)

        #expect(sut.isSynopsisExpanded == false)
    }


    //#################################################################################
    // MARK: - loadDetails Tests
    //#################################################################################

    @Test("loadDetails calls AniList service")
    func loadDetails_callsAniListService() async {
        let mockAniListService = MockAniListService()
        let item = TestFixtures.makeRecommendingItem(anilistId: 12345)
        let sut = AnimeDetailViewModel(item: item, aniListService: mockAniListService)

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
        let item = TestFixtures.makeRecommendingItem()
        let sut = AnimeDetailViewModel(item: item, aniListService: mockAniListService)

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
        let item = TestFixtures.makeRecommendingItem()
        let sut = AnimeDetailViewModel(item: item, aniListService: mockAniListService)

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
        let item = TestFixtures.makeRecommendingItem()
        let sut = AnimeDetailViewModel(item: item, aniListService: mockAniListService)

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
        let item = TestFixtures.makeRecommendingItem()
        let sut = AnimeDetailViewModel(item: item, aniListService: mockAniListService)

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
        let item = TestFixtures.makeRecommendingItem()
        let sut = AnimeDetailViewModel(item: item, aniListService: mockAniListService)

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
        let item = TestFixtures.makeRecommendingItem()
        let sut = AnimeDetailViewModel(item: item, aniListService: mockAniListService)

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
        let item = TestFixtures.makeRecommendingItem()
        let sut = AnimeDetailViewModel(item: item, aniListService: mockAniListService)

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
        let mockAniListService = MockAniListService()
        let item = TestFixtures.makeRecommendingItem(title: "Preview Title")
        let sut = AnimeDetailViewModel(item: item, aniListService: mockAniListService)

        #expect(sut.displayTitle == "Preview Title")
    }

    @Test("displayTitle returns anime title when loaded")
    func displayTitle_returnsAnimeTitleWhenLoaded() async {
        let mockAniListService = MockAniListService()
        let item = TestFixtures.makeRecommendingItem(title: "Preview Title")
        let sut = AnimeDetailViewModel(item: item, aniListService: mockAniListService)

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
        let mockAniListService = MockAniListService()
        let item = TestFixtures.makeRecommendingItem()
        let sut = AnimeDetailViewModel(item: item, aniListService: mockAniListService)

        #expect(sut.displayCoverURL == item.coverURL)
    }

    @Test("displayCoverURL returns anime coverURL when loaded")
    func displayCoverURL_returnsAnimeCoverURLWhenLoaded() async {
        let mockAniListService = MockAniListService()
        let item = TestFixtures.makeRecommendingItem()
        let sut = AnimeDetailViewModel(item: item, aniListService: mockAniListService)

        // Given
        let anime = TestFixtures.makeAniListAnimeDetail()
        mockAniListService.fetchAnimeDetailsResult = .success(anime)

        // When
        await sut.loadDetails()

        // Then
        #expect(sut.displayCoverURL == anime.coverURL)
    }
}
