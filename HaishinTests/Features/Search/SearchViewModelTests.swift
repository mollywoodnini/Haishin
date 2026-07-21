//
//  SearchViewModelTests.swift
//  HaishinTests
//
//  Created by Tan Nghia La on 24.01.26.
//

import Foundation
import Testing
@testable import Haishin


//#################################################################################
// MARK: - MockAniListService
//#################################################################################

/// Mock implementation of AniListServicing for testing.
final class MockAniListService: AniListServicing {

    var searchResult: Result<PaginatedResponse, Error> = .success(
        PaginatedResponse(items: [], hasNextPage: false, currentPage: 1)
    )
    var searchCallCount = 0
    var searchQueries: [String] = []
    var searchPages: [Int] = []

    func fetchThisWeek(showNSFW: Bool) async throws -> [RecommendingItem] { [] }
    func fetchTrending(page: Int, showNSFW: Bool) async throws -> PaginatedResponse {
        PaginatedResponse(items: [], hasNextPage: false, currentPage: page)
    }
    func fetchSeasonal(page: Int, showNSFW: Bool) async throws -> PaginatedResponse {
        PaginatedResponse(items: [], hasNextPage: false, currentPage: page)
    }
    func fetchAnimeDetails(id: Int) async throws -> AniListAnimeDetail {
        throw MockError.notConfigured
    }

    func search(query: String, page: Int, showNSFW: Bool) async throws -> PaginatedResponse {
        searchCallCount += 1
        searchQueries.append(query)
        searchPages.append(page)
        return try searchResult.get()
    }
}


//#################################################################################
// MARK: - SearchViewModel Tests
//#################################################################################

@Suite("SearchViewModel Tests")
@MainActor
struct SearchViewModelTests {

    //#################################################################################
    // MARK: - Helper
    //#################################################################################

    private func makeSUT(aniListService: MockAniListService? = nil) -> SearchViewModel {
        SearchViewModel(
            aniListService: aniListService ?? MockAniListService(),
            debounceMilliseconds: 0
        )
    }


    //#################################################################################
    // MARK: - Initialization Tests
    //#################################################################################

    @Test("On initialization, results is empty")
    func initialization_resultsIsEmpty() {
        let sut = makeSUT()

        #expect(sut.results.isEmpty == true)
    }

    @Test("On initialization, isSearching is false")
    func initialization_isSearchingIsFalse() {
        let sut = makeSUT()

        #expect(sut.isSearching == false)
    }

    @Test("On initialization, error is nil")
    func initialization_errorIsNil() {
        let sut = makeSUT()

        #expect(sut.error == nil)
    }


    //#################################################################################
    // MARK: - search Tests
    //#################################################################################

    @Test("search with empty query clears results")
    func search_withEmptyQuery_clearsResults() {
        let mockAniList = MockAniListService()
        let sut = makeSUT(aniListService: mockAniList)

        sut.search(query: "")

        #expect(sut.results.isEmpty == true)
        #expect(mockAniList.searchCallCount == 0)
        #expect(sut.error == nil)
    }

    @Test("search with whitespace only query clears results")
    func search_withWhitespaceOnlyQuery_clearsResults() {
        let mockAniList = MockAniListService()
        let sut = makeSUT(aniListService: mockAniList)

        sut.search(query: "   ")

        #expect(sut.results.isEmpty == true)
        #expect(mockAniList.searchCallCount == 0)
    }

    @Test("search with valid query populates results")
    func search_withValidQuery_populatesResults() async throws {
        let mockAniList = MockAniListService()
        let sut = makeSUT(aniListService: mockAniList)

        let expectedItem = RecommendingItem(
            id: "1",
            title: "Naruto",
            coverURL: URL(string: "https://example.com/cover.jpg"),
            anilistId: 1
        )
        mockAniList.searchResult = .success(
            PaginatedResponse(items: [expectedItem], hasNextPage: false, currentPage: 1)
        )

        sut.search(query: "Naruto")
        try await Task.sleep(for: .milliseconds(50))

        #expect(sut.results.count == 1)
        #expect(sut.results.first?.title == "Naruto")
        #expect(mockAniList.searchCallCount == 1)
        #expect(mockAniList.searchQueries.first == "Naruto")
    }

    @Test("search sets error when service fails")
    func search_setsErrorWhenServiceFails() async throws {
        let mockAniList = MockAniListService()
        let sut = makeSUT(aniListService: mockAniList)

        mockAniList.searchResult = .failure(MockError.testError)

        sut.search(query: "Naruto")
        try await Task.sleep(for: .milliseconds(50))

        #expect(sut.results.isEmpty == true)
        #expect(sut.error != nil)
        #expect(mockAniList.searchCallCount == 1)
    }

    @Test("search updates isSearching during and after search")
    func search_updatesIsSearching() async throws {
        let mockAniList = MockAniListService()
        let sut = makeSUT(aniListService: mockAniList)

        #expect(sut.isSearching == false)

        sut.search(query: "Naruto")
        #expect(sut.isSearching == true)

        try await Task.sleep(for: .milliseconds(50))
        #expect(sut.isSearching == false)
    }

    @Test("search prevents duplicate searches for same query")
    func search_preventsDuplicateSearches() async throws {
        let mockAniList = MockAniListService()
        let sut = makeSUT(aniListService: mockAniList)

        sut.search(query: "Naruto")
        try await Task.sleep(for: .milliseconds(50))

        sut.search(query: "Naruto")
        try await Task.sleep(for: .milliseconds(50))

        #expect(mockAniList.searchCallCount == 1)
    }

    @Test("search with different queries updates results")
    func search_withDifferentQueries_updatesResults() async throws {
        let mockAniList = MockAniListService()
        let sut = makeSUT(aniListService: mockAniList)

        sut.search(query: "Naruto")
        try await Task.sleep(for: .milliseconds(50))

        sut.search(query: "One Piece")
        try await Task.sleep(for: .milliseconds(50))

        #expect(mockAniList.searchQueries.contains("One Piece"))
        #expect(mockAniList.searchCallCount == 2)
    }
}
