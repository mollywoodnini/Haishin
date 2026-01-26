//
//  AnimeListViewModelTests.swift
//  HaishinTests
//
//  Created by Haishin on 24.01.26.
//

import Testing
@testable import Haishin


@Suite("AnimeListViewModel Tests")
@MainActor
struct AnimeListViewModelTests {

    //#################################################################################
    // MARK: - Helper
    //#################################################################################

    /// Creates a fresh AnimeListViewModel with mocks.
    private func makeSUT(title: String = "Trending",
                         listType: AnimeListType = .trending,
                         mockService: MockAniListService? = nil,
                         mockUserPreferences: MockUserPreferences? = nil) -> AnimeListViewModel {
        AnimeListViewModel(title: title,
                           listType: listType,
                           aniListService: mockService ?? MockAniListService(),
                           userPreferences: mockUserPreferences ?? MockUserPreferences())
    }


    //#################################################################################
    // MARK: - Initialization Tests
    //#################################################################################

    @Test("On initialization, title is set")
    func onInitialization_titleIsSet() {
        let sut = makeSUT(title: "Trending")

        #expect(sut.title == "Trending")
    }

    @Test("On initialization, listType is set")
    func onInitialization_listTypeIsSet() {
        let sut = makeSUT(listType: .trending)

        #expect(sut.listType == .trending)
    }

    @Test("On initialization, items is empty")
    func onInitialization_itemsIsEmpty() {
        let sut = makeSUT()

        #expect(sut.items.isEmpty)
    }

    @Test("On initialization, isLoading is false")
    func onInitialization_isLoadingIsFalse() {
        let sut = makeSUT()

        #expect(sut.isLoading == false)
    }

    @Test("On initialization, isLoadingMore is false")
    func onInitialization_isLoadingMoreIsFalse() {
        let sut = makeSUT()

        #expect(sut.isLoadingMore == false)
    }

    @Test("On initialization, hasMorePages is true")
    func onInitialization_hasMorePagesIsTrue() {
        let sut = makeSUT()

        #expect(sut.hasMorePages == true)
    }

    @Test("On initialization, error is nil")
    func onInitialization_errorIsNil() {
        let sut = makeSUT()

        #expect(sut.error == nil)
    }


    //#################################################################################
    // MARK: - loadInitialContent Tests
    //#################################################################################

    @Test("loadInitialContent calls AniList service")
    func loadInitialContent_callsAniListService() async {
        let mockService = MockAniListService()
        let sut = makeSUT(mockService: mockService)

        let items = [TestFixtures.makeRecommendingItem()]
        mockService.fetchTrendingResult = .success(PaginatedResponse(items: items,
                                                                      hasNextPage: true,
                                                                      currentPage: 1))

        await sut.loadInitialContent()

        #expect(mockService.fetchTrendingCallCount == 1)
        #expect(mockService.fetchTrendingPages == [1])
    }

    @Test("loadInitialContent with seasonal type calls fetchSeasonal")
    func loadInitialContent_withSeasonalType_callsFetchSeasonal() async {
        let mockService = MockAniListService()
        let sut = makeSUT(title: "Seasonal", listType: .seasonal, mockService: mockService)

        let items = [TestFixtures.makeRecommendingItem()]
        mockService.fetchSeasonalResult = .success(PaginatedResponse(items: items,
                                                                      hasNextPage: true,
                                                                      currentPage: 1))

        await sut.loadInitialContent()

        #expect(mockService.fetchSeasonalCallCount == 1)
        #expect(mockService.fetchSeasonalPages == [1])
    }

    @Test("loadInitialContent on success populates items")
    func loadInitialContent_onSuccess_populatesItems() async {
        let mockService = MockAniListService()
        let sut = makeSUT(mockService: mockService)

        let item1 = TestFixtures.makeRecommendingItem(id: "1", title: "Anime 1")
        let item2 = TestFixtures.makeRecommendingItem(id: "2", title: "Anime 2")
        mockService.fetchTrendingResult = .success(PaginatedResponse(items: [item1, item2],
                                                                      hasNextPage: true,
                                                                      currentPage: 1))

        await sut.loadInitialContent()

        #expect(sut.items.count == 2)
        #expect(sut.items[0].title == "Anime 1")
        #expect(sut.items[1].title == "Anime 2")
    }

    @Test("loadInitialContent on success sets hasMorePages")
    func loadInitialContent_onSuccess_setsHasMorePages() async {
        let mockService = MockAniListService()
        let sut = makeSUT(mockService: mockService)

        mockService.fetchTrendingResult = .success(PaginatedResponse(items: [],
                                                                      hasNextPage: false,
                                                                      currentPage: 1))

        await sut.loadInitialContent()

        #expect(sut.hasMorePages == false)
    }

    @Test("loadInitialContent on success sets isLoading to false")
    func loadInitialContent_onSuccess_setsIsLoadingToFalse() async {
        let mockService = MockAniListService()
        let sut = makeSUT(mockService: mockService)

        mockService.fetchTrendingResult = .success(PaginatedResponse(items: [],
                                                                      hasNextPage: false,
                                                                      currentPage: 1))

        await sut.loadInitialContent()

        #expect(sut.isLoading == false)
    }

    @Test("loadInitialContent on error sets error")
    func loadInitialContent_onError_setsError() async {
        let mockService = MockAniListService()
        let sut = makeSUT(mockService: mockService)

        mockService.fetchTrendingResult = .failure(MockError.testError)

        await sut.loadInitialContent()

        #expect(sut.error != nil)
    }

    @Test("loadInitialContent on error sets isLoading to false")
    func loadInitialContent_onError_setsIsLoadingToFalse() async {
        let mockService = MockAniListService()
        let sut = makeSUT(mockService: mockService)

        mockService.fetchTrendingResult = .failure(MockError.testError)

        await sut.loadInitialContent()

        #expect(sut.isLoading == false)
    }

    @Test("loadInitialContent when items exist does not load")
    func loadInitialContent_whenItemsExist_doesNotLoad() async {
        let mockService = MockAniListService()
        let sut = makeSUT(mockService: mockService)

        mockService.fetchTrendingResult = .success(PaginatedResponse(items: [TestFixtures.makeRecommendingItem()],
                                                                      hasNextPage: true,
                                                                      currentPage: 1))
        await sut.loadInitialContent()
        #expect(mockService.fetchTrendingCallCount == 1)

        await sut.loadInitialContent()

        #expect(mockService.fetchTrendingCallCount == 1)
    }


    //#################################################################################
    // MARK: - loadMore Tests
    //#################################################################################

    @Test("loadMore calls AniList service with next page")
    func loadMore_callsAniListServiceWithNextPage() async {
        let mockService = MockAniListService()
        let sut = makeSUT(mockService: mockService)

        mockService.fetchTrendingResult = .success(PaginatedResponse(items: [TestFixtures.makeRecommendingItem()],
                                                                      hasNextPage: true,
                                                                      currentPage: 1))
        await sut.loadInitialContent()

        await sut.loadMore()

        #expect(mockService.fetchTrendingCallCount == 2)
        #expect(mockService.fetchTrendingPages == [1, 2])
    }

    @Test("loadMore appends items to existing")
    func loadMore_appendsItemsToExisting() async {
        let mockService = MockAniListService()
        let sut = makeSUT(mockService: mockService)

        let item1 = TestFixtures.makeRecommendingItem(id: "1", title: "Anime 1")
        mockService.fetchTrendingResult = .success(PaginatedResponse(items: [item1],
                                                                      hasNextPage: true,
                                                                      currentPage: 1))
        await sut.loadInitialContent()
        #expect(sut.items.count == 1)

        let item2 = TestFixtures.makeRecommendingItem(id: "2", title: "Anime 2")
        mockService.fetchTrendingResult = .success(PaginatedResponse(items: [item2],
                                                                      hasNextPage: false,
                                                                      currentPage: 2))
        await sut.loadMore()

        #expect(sut.items.count == 2)
        #expect(sut.items[0].title == "Anime 1")
        #expect(sut.items[1].title == "Anime 2")
    }

    @Test("loadMore updates hasMorePages")
    func loadMore_updatesHasMorePages() async {
        let mockService = MockAniListService()
        let sut = makeSUT(mockService: mockService)

        mockService.fetchTrendingResult = .success(PaginatedResponse(items: [TestFixtures.makeRecommendingItem()],
                                                                      hasNextPage: true,
                                                                      currentPage: 1))
        await sut.loadInitialContent()
        #expect(sut.hasMorePages == true)

        mockService.fetchTrendingResult = .success(PaginatedResponse(items: [],
                                                                      hasNextPage: false,
                                                                      currentPage: 2))
        await sut.loadMore()

        #expect(sut.hasMorePages == false)
    }

    @Test("loadMore when no more pages does not load")
    func loadMore_whenNoMorePages_doesNotLoad() async {
        let mockService = MockAniListService()
        let sut = makeSUT(mockService: mockService)

        mockService.fetchTrendingResult = .success(PaginatedResponse(items: [TestFixtures.makeRecommendingItem()],
                                                                      hasNextPage: false,
                                                                      currentPage: 1))
        await sut.loadInitialContent()
        #expect(mockService.fetchTrendingCallCount == 1)

        await sut.loadMore()

        #expect(mockService.fetchTrendingCallCount == 1)
    }

    @Test("loadMore on error sets error")
    func loadMore_onError_setsError() async {
        let mockService = MockAniListService()
        let sut = makeSUT(mockService: mockService)

        mockService.fetchTrendingResult = .success(PaginatedResponse(items: [TestFixtures.makeRecommendingItem()],
                                                                      hasNextPage: true,
                                                                      currentPage: 1))
        await sut.loadInitialContent()

        mockService.fetchTrendingResult = .failure(MockError.testError)
        await sut.loadMore()

        #expect(sut.error != nil)
    }

    @Test("loadMore on error sets isLoadingMore to false")
    func loadMore_onError_setsIsLoadingMoreToFalse() async {
        let mockService = MockAniListService()
        let sut = makeSUT(mockService: mockService)

        mockService.fetchTrendingResult = .success(PaginatedResponse(items: [TestFixtures.makeRecommendingItem()],
                                                                      hasNextPage: true,
                                                                      currentPage: 1))
        await sut.loadInitialContent()

        mockService.fetchTrendingResult = .failure(MockError.testError)
        await sut.loadMore()

        #expect(sut.isLoadingMore == false)
    }


    //#################################################################################
    // MARK: - loadMoreIfNeeded Tests
    //#################################################################################

    @Test("loadMoreIfNeeded when near end loads more")
    func loadMoreIfNeeded_whenNearEnd_loadsMore() async {
        let mockService = MockAniListService()
        let sut = makeSUT(mockService: mockService)

        var items: [RecommendingItem] = []
        for i in 1...6 {
            items.append(TestFixtures.makeRecommendingItem(id: "\(i)", title: "Anime \(i)"))
        }
        mockService.fetchTrendingResult = .success(PaginatedResponse(items: items,
                                                                      hasNextPage: true,
                                                                      currentPage: 1))
        await sut.loadInitialContent()
        #expect(mockService.fetchTrendingCallCount == 1)

        let itemNearEnd = sut.items[1]
        await sut.loadMoreIfNeeded(currentItem: itemNearEnd)

        #expect(mockService.fetchTrendingCallCount == 2)
    }

    @Test("loadMoreIfNeeded when not near end does not load")
    func loadMoreIfNeeded_whenNotNearEnd_doesNotLoad() async {
        let mockService = MockAniListService()
        let sut = makeSUT(mockService: mockService)

        var items: [RecommendingItem] = []
        for i in 1...10 {
            items.append(TestFixtures.makeRecommendingItem(id: "\(i)", title: "Anime \(i)"))
        }
        mockService.fetchTrendingResult = .success(PaginatedResponse(items: items,
                                                                      hasNextPage: true,
                                                                      currentPage: 1))
        await sut.loadInitialContent()
        #expect(mockService.fetchTrendingCallCount == 1)

        let itemAtStart = sut.items[0]
        await sut.loadMoreIfNeeded(currentItem: itemAtStart)

        #expect(mockService.fetchTrendingCallCount == 1)
    }

    @Test("loadMoreIfNeeded with non-existent item does not load")
    func loadMoreIfNeeded_withNonExistentItem_doesNotLoad() async {
        let mockService = MockAniListService()
        let sut = makeSUT(mockService: mockService)

        mockService.fetchTrendingResult = .success(PaginatedResponse(items: [TestFixtures.makeRecommendingItem()],
                                                                      hasNextPage: true,
                                                                      currentPage: 1))
        await sut.loadInitialContent()
        #expect(mockService.fetchTrendingCallCount == 1)

        let unknownItem = TestFixtures.makeRecommendingItem(id: "unknown")
        await sut.loadMoreIfNeeded(currentItem: unknownItem)

        #expect(mockService.fetchTrendingCallCount == 1)
    }


    //#################################################################################
    // MARK: - refresh Tests
    //#################################################################################

    @Test("refresh clears items and reloads")
    func refresh_clearsItemsAndReloads() async {
        let mockService = MockAniListService()
        let sut = makeSUT(mockService: mockService)

        mockService.fetchTrendingResult = .success(PaginatedResponse(items: [TestFixtures.makeRecommendingItem(id: "1")],
                                                                      hasNextPage: false,
                                                                      currentPage: 1))
        await sut.loadInitialContent()
        #expect(sut.items.count == 1)
        #expect(mockService.fetchTrendingCallCount == 1)

        mockService.fetchTrendingResult = .success(PaginatedResponse(items: [TestFixtures.makeRecommendingItem(id: "2", title: "New Anime")],
                                                                      hasNextPage: true,
                                                                      currentPage: 1))
        await sut.refresh()

        #expect(mockService.fetchTrendingCallCount == 2)
        #expect(sut.items.count == 1)
        #expect(sut.items.first?.title == "New Anime")
    }

    @Test("refresh resets hasMorePages")
    func refresh_resetsHasMorePages() async {
        let mockService = MockAniListService()
        let sut = makeSUT(mockService: mockService)

        mockService.fetchTrendingResult = .success(PaginatedResponse(items: [TestFixtures.makeRecommendingItem()],
                                                                      hasNextPage: false,
                                                                      currentPage: 1))
        await sut.loadInitialContent()
        #expect(sut.hasMorePages == false)

        mockService.fetchTrendingResult = .success(PaginatedResponse(items: [],
                                                                      hasNextPage: true,
                                                                      currentPage: 1))
        await sut.refresh()

        #expect(sut.hasMorePages == true)
    }

    @Test("refresh clears error")
    func refresh_clearsError() async {
        let mockService = MockAniListService()
        let sut = makeSUT(mockService: mockService)

        mockService.fetchTrendingResult = .failure(MockError.testError)
        await sut.loadInitialContent()
        #expect(sut.error != nil)

        mockService.fetchTrendingResult = .success(PaginatedResponse(items: [],
                                                                      hasNextPage: false,
                                                                      currentPage: 1))
        await sut.refresh()

        #expect(sut.error == nil)
    }

    @Test("refresh resets page to one")
    func refresh_resetsPageToOne() async {
        let mockService = MockAniListService()
        let sut = makeSUT(mockService: mockService)

        mockService.fetchTrendingResult = .success(PaginatedResponse(items: [TestFixtures.makeRecommendingItem()],
                                                                      hasNextPage: true,
                                                                      currentPage: 1))
        await sut.loadInitialContent()
        await sut.loadMore()
        #expect(mockService.fetchTrendingPages == [1, 2])

        mockService.fetchTrendingPages = []
        await sut.refresh()

        #expect(mockService.fetchTrendingPages == [1])
    }
}
