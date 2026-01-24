//
//  SearchViewModelTests.swift
//  MiruTests
//
//  Created by Miru on 24.01.26.
//

import XCTest
@testable import Miru

final class SearchViewModelTests: XCTestCase {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    var sut: SearchViewModel!
    var mockSourceManager: MockSourceManager!


    //#################################################################################
    // MARK: - Setup & Teardown
    //#################################################################################

    override func setUp() {
        super.setUp()
        mockSourceManager = MockSourceManager()
        sut = SearchViewModel(sourceManager: mockSourceManager)
    }

    override func tearDown() {
        sut = nil
        mockSourceManager = nil
        super.tearDown()
    }


    //#################################################################################
    // MARK: - Initialization Tests
    //#################################################################################

    func test_onInitialization_resultsIsEmpty() {
        XCTAssertTrue(sut.results.isEmpty)
    }

    func test_onInitialization_isSearchingIsFalse() {
        XCTAssertFalse(sut.isSearching)
    }

    func test_onInitialization_errorIsNil() {
        XCTAssertNil(sut.error)
    }


    //#################################################################################
    // MARK: - search Tests
    //#################################################################################

    func test_search_withEmptyQuery_clearsResults() async {
        // Given - Set some initial results
        mockSourceManager.searchResult = .success([TestFixtures.makeAnimePreview()])

        // When
        await sut.search(query: "")

        // Then
        XCTAssertTrue(sut.results.isEmpty)
        XCTAssertEqual(mockSourceManager.searchCallCount, 0)
    }

    func test_search_withWhitespaceOnlyQuery_clearsResults() async {
        // When
        await sut.search(query: "   ")

        // Then
        XCTAssertTrue(sut.results.isEmpty)
        XCTAssertEqual(mockSourceManager.searchCallCount, 0)
    }

    func test_search_withValidQuery_returnsResults() async {
        // Given
        let source = TestFixtures.makeInstalledSource(isEnabled: true)
        mockSourceManager.installedSources = [source]
        let expectedAnime = TestFixtures.makeAnimePreview(title: "Naruto")
        mockSourceManager.searchResult = .success([expectedAnime])

        // When
        await sut.search(query: "Naruto")

        // Wait for debounce
        try? await Task.sleep(for: .milliseconds(400))

        // Then
        XCTAssertEqual(mockSourceManager.searchCallCount, 1)
        XCTAssertEqual(mockSourceManager.searchQueries.first, "Naruto")
    }

    func test_search_withDisabledSources_doesNotSearch() async {
        // Given
        let source = TestFixtures.makeInstalledSource(isEnabled: false)
        mockSourceManager.installedSources = [source]

        // When
        await sut.search(query: "Test")

        // Wait for debounce
        try? await Task.sleep(for: .milliseconds(400))

        // Then - Search is performed on enabled sources only
        XCTAssertEqual(mockSourceManager.searchCallCount, 0)
    }

    func test_search_withMultipleSources_searchesAllEnabled() async {
        // Given
        let source1 = TestFixtures.makeInstalledSource(id: "source1", isEnabled: true)
        let source2 = TestFixtures.makeInstalledSource(id: "source2", isEnabled: true)
        let source3 = TestFixtures.makeInstalledSource(id: "source3", isEnabled: false)
        mockSourceManager.installedSources = [source1, source2, source3]
        mockSourceManager.searchResult = .success([TestFixtures.makeAnimePreview()])

        // When
        await sut.search(query: "Test")

        // Wait for debounce
        try? await Task.sleep(for: .milliseconds(400))

        // Then - Should search in 2 enabled sources
        XCTAssertEqual(mockSourceManager.searchCallCount, 2)
    }

    func test_search_cancelsExistingSearch() async {
        // Given
        let source = TestFixtures.makeInstalledSource(isEnabled: true)
        mockSourceManager.installedSources = [source]
        mockSourceManager.searchResult = .success([TestFixtures.makeAnimePreview()])

        // When - Start searches in quick succession
        await sut.search(query: "first")
        await sut.search(query: "second")

        // Wait for debounce
        try? await Task.sleep(for: .milliseconds(400))

        // Then - Only the last search should complete
        XCTAssertEqual(mockSourceManager.searchQueries.last, "second")
    }
}
