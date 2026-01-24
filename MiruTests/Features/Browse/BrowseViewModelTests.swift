//
//  BrowseViewModelTests.swift
//  MiruTests
//
//  Created by Miru on 24.01.26.
//

import XCTest
@testable import Miru

@MainActor
final class BrowseViewModelTests: XCTestCase {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    var sut: BrowseViewModel!
    var mockSourceManager: MockSourceManager!
    var mockAniListService: MockAniListService!


    //#################################################################################
    // MARK: - Setup & Teardown
    //#################################################################################

    override func setUp() {
        super.setUp()
        mockSourceManager = MockSourceManager()
        mockAniListService = MockAniListService()
        sut = BrowseViewModel(sourceManager: mockSourceManager,
                              aniListService: mockAniListService)
    }

    override func tearDown() {
        sut = nil
        mockAniListService = nil
        mockSourceManager = nil
        super.tearDown()
    }


    //#################################################################################
    // MARK: - Initialization Tests
    //#################################################################################

    func test_onInitialization_sectionsAreInitialized() {
        XCTAssertEqual(sut.sections.count, 3)
    }

    func test_onInitialization_sectionsHaveCorrectIds() {
        let sectionIds = sut.sections.map { $0.id }
        XCTAssertTrue(sectionIds.contains("this-week"))
        XCTAssertTrue(sectionIds.contains("trending"))
        XCTAssertTrue(sectionIds.contains("seasonal"))
    }

    func test_onInitialization_sectionsHaveCorrectTitles() {
        let titles = sut.sections.map { $0.title }
        XCTAssertTrue(titles.contains("This Week"))
        XCTAssertTrue(titles.contains("Trending"))
        XCTAssertTrue(titles.contains("Seasonal Anime"))
    }

    func test_onInitialization_sectionsHaveCorrectStyles() {
        let thisWeekSection = sut.sections.first { $0.id == "this-week" }
        let trendingSection = sut.sections.first { $0.id == "trending" }
        let seasonalSection = sut.sections.first { $0.id == "seasonal" }

        XCTAssertEqual(thisWeekSection?.style, .thisWeek)
        XCTAssertEqual(trendingSection?.style, .standard)
        XCTAssertEqual(seasonalSection?.style, .standard)
    }

    func test_onInitialization_sectionsAreEmpty() {
        for section in sut.sections {
            XCTAssertTrue(section.items.isEmpty)
        }
    }

    func test_onInitialization_isLoadingIsFalse() {
        XCTAssertFalse(sut.isLoading)
    }

    func test_onInitialization_errorIsNil() {
        XCTAssertNil(sut.error)
    }


    //#################################################################################
    // MARK: - installedSources Tests
    //#################################################################################

    func test_installedSources_returnsSourceManagerSources() {
        // Given
        let source = TestFixtures.makeInstalledSource()
        mockSourceManager.installedSources = [source]

        // Then
        XCTAssertEqual(sut.installedSources.count, 1)
        XCTAssertEqual(sut.installedSources.first?.id, source.id)
    }


    //#################################################################################
    // MARK: - loadContent Tests
    //#################################################################################

    func test_loadContent_callsAllAniListServiceMethods() async {
        // Given
        mockAniListService.fetchThisWeekResult = .success([TestFixtures.makeRecommendingItem()])
        mockAniListService.fetchTrendingResult = .success(PaginatedResponse(items: [TestFixtures.makeRecommendingItem(id: "2")], hasNextPage: false, currentPage: 1))
        mockAniListService.fetchSeasonalResult = .success(PaginatedResponse(items: [TestFixtures.makeRecommendingItem(id: "3")], hasNextPage: false, currentPage: 1))

        // When
        await sut.loadContent()

        // Then
        XCTAssertEqual(mockAniListService.fetchThisWeekCallCount, 1)
        XCTAssertEqual(mockAniListService.fetchTrendingCallCount, 1)
        XCTAssertEqual(mockAniListService.fetchSeasonalCallCount, 1)
    }

    func test_loadContent_populatesSections() async {
        // Given
        let thisWeekItem = TestFixtures.makeRecommendingItem(id: "1", title: "This Week Anime")
        let trendingItem = TestFixtures.makeRecommendingItem(id: "2", title: "Trending Anime")
        let seasonalItem = TestFixtures.makeRecommendingItem(id: "3", title: "Seasonal Anime")

        mockAniListService.fetchThisWeekResult = .success([thisWeekItem])
        mockAniListService.fetchTrendingResult = .success(PaginatedResponse(items: [trendingItem], hasNextPage: false, currentPage: 1))
        mockAniListService.fetchSeasonalResult = .success(PaginatedResponse(items: [seasonalItem], hasNextPage: false, currentPage: 1))

        // When
        await sut.loadContent()

        // Then
        let thisWeekSection = sut.sections.first { $0.id == "this-week" }
        let trendingSection = sut.sections.first { $0.id == "trending" }
        let seasonalSection = sut.sections.first { $0.id == "seasonal" }

        XCTAssertEqual(thisWeekSection?.items.count, 1)
        XCTAssertEqual(thisWeekSection?.items.first?.title, "This Week Anime")

        XCTAssertEqual(trendingSection?.items.count, 1)
        XCTAssertEqual(trendingSection?.items.first?.title, "Trending Anime")

        XCTAssertEqual(seasonalSection?.items.count, 1)
        XCTAssertEqual(seasonalSection?.items.first?.title, "Seasonal Anime")
    }

    func test_loadContent_setsLoadingStateToLoaded() async {
        // Given
        mockAniListService.fetchThisWeekResult = .success([])
        mockAniListService.fetchTrendingResult = .success(PaginatedResponse(items: [], hasNextPage: false, currentPage: 1))
        mockAniListService.fetchSeasonalResult = .success(PaginatedResponse(items: [], hasNextPage: false, currentPage: 1))

        // When
        await sut.loadContent()

        // Then
        for section in sut.sections {
            XCTAssertEqual(section.loadingState, .loaded)
        }
    }

    func test_loadContent_setsLoadingStateToFailedOnError() async {
        // Given
        mockAniListService.fetchThisWeekResult = .failure(MockError.testError)
        mockAniListService.fetchTrendingResult = .success(PaginatedResponse(items: [], hasNextPage: false, currentPage: 1))
        mockAniListService.fetchSeasonalResult = .success(PaginatedResponse(items: [], hasNextPage: false, currentPage: 1))

        // When
        await sut.loadContent()

        // Then
        let thisWeekSection = sut.sections.first { $0.id == "this-week" }
        XCTAssertNotEqual(thisWeekSection?.loadingState, .loaded)
    }

    func test_loadContent_whenAlreadyLoading_doesNotLoadAgain() async {
        // Given
        mockAniListService.fetchThisWeekResult = .success([])
        mockAniListService.fetchTrendingResult = .success(PaginatedResponse(items: [], hasNextPage: false, currentPage: 1))
        mockAniListService.fetchSeasonalResult = .success(PaginatedResponse(items: [], hasNextPage: false, currentPage: 1))

        // When - Start first load
        let task1 = Task {
            await sut.loadContent()
        }

        // Slight delay to ensure first task starts
        try? await Task.sleep(for: .milliseconds(10))

        // Start second load while first is in progress
        let task2 = Task {
            await sut.loadContent()
        }

        await task1.value
        await task2.value

        // Then - Should only load once
        XCTAssertEqual(mockAniListService.fetchThisWeekCallCount, 1)
    }


    //#################################################################################
    // MARK: - refresh Tests
    //#################################################################################

    func test_refresh_resetsAndReloadsSections() async {
        // Given - Load initial content
        mockAniListService.fetchThisWeekResult = .success([TestFixtures.makeRecommendingItem()])
        mockAniListService.fetchTrendingResult = .success(PaginatedResponse(items: [TestFixtures.makeRecommendingItem(id: "2")], hasNextPage: false, currentPage: 1))
        mockAniListService.fetchSeasonalResult = .success(PaginatedResponse(items: [TestFixtures.makeRecommendingItem(id: "3")], hasNextPage: false, currentPage: 1))

        await sut.loadContent()

        XCTAssertEqual(mockAniListService.fetchThisWeekCallCount, 1)

        // When
        await sut.refresh()

        // Then - Should have reloaded
        XCTAssertEqual(mockAniListService.fetchThisWeekCallCount, 2)
        XCTAssertEqual(mockAniListService.fetchTrendingCallCount, 2)
        XCTAssertEqual(mockAniListService.fetchSeasonalCallCount, 2)
    }
}
