//
//  SearchViewModelTests.swift
//  MiruTests
//
//  Created by Miru on 24.01.26.
//

import Testing
@testable import Miru


//#################################################################################
// MARK: - SearchViewModel Tests
//#################################################################################

@Suite("SearchViewModel Tests")
@MainActor
struct SearchViewModelTests {

    //#################################################################################
    // MARK: - Initialization Tests
    //#################################################################################

    @Test("On initialization, results is empty")
    func initialization_resultsIsEmpty() {
        let mockSourceManager = MockSourceManager()
        let sut = SearchViewModel(sourceManager: mockSourceManager, debounceMilliseconds: 0)

        #expect(sut.results.isEmpty == true)
    }

    @Test("On initialization, isSearching is false")
    func initialization_isSearchingIsFalse() {
        let mockSourceManager = MockSourceManager()
        let sut = SearchViewModel(sourceManager: mockSourceManager, debounceMilliseconds: 0)

        #expect(sut.isSearching == false)
    }

    @Test("On initialization, error is nil")
    func initialization_errorIsNil() {
        let mockSourceManager = MockSourceManager()
        let sut = SearchViewModel(sourceManager: mockSourceManager, debounceMilliseconds: 0)

        #expect(sut.error == nil)
    }


    //#################################################################################
    // MARK: - search Tests
    //#################################################################################

    @Test("search with empty query clears results")
    func search_withEmptyQuery_clearsResults() async {
        let mockSourceManager = MockSourceManager()
        let sut = SearchViewModel(sourceManager: mockSourceManager, debounceMilliseconds: 0)

        // Given - Set some initial results
        mockSourceManager.searchResult = .success([TestFixtures.makeAnimePreview()])

        // When
        await sut.search(query: "")

        // Then
        #expect(sut.results.isEmpty == true)
        #expect(mockSourceManager.searchCallCount == 0)
    }

    @Test("search with whitespace only query clears results")
    func search_withWhitespaceOnlyQuery_clearsResults() async {
        let mockSourceManager = MockSourceManager()
        let sut = SearchViewModel(sourceManager: mockSourceManager, debounceMilliseconds: 0)

        // When
        await sut.search(query: "   ")

        // Then
        #expect(sut.results.isEmpty == true)
        #expect(mockSourceManager.searchCallCount == 0)
    }

    @Test("search with valid query returns results")
    func search_withValidQuery_returnsResults() async {
        let mockSourceManager = MockSourceManager()
        let sut = SearchViewModel(sourceManager: mockSourceManager, debounceMilliseconds: 0)

        // Given
        let source = TestFixtures.makeInstalledSource(isEnabled: true)
        mockSourceManager.installedSources = [source]
        let expectedAnime = TestFixtures.makeAnimePreview(title: "Naruto")
        mockSourceManager.searchResult = .success([expectedAnime])

        // When
        await sut.search(query: "Naruto")

        // Then
        #expect(mockSourceManager.searchCallCount == 1)
        #expect(mockSourceManager.searchQueries.first == "Naruto")
    }

    @Test("search with disabled sources does not search")
    func search_withDisabledSources_doesNotSearch() async {
        let mockSourceManager = MockSourceManager()
        let sut = SearchViewModel(sourceManager: mockSourceManager, debounceMilliseconds: 0)

        // Given
        let source = TestFixtures.makeInstalledSource(isEnabled: false)
        mockSourceManager.installedSources = [source]

        // When
        await sut.search(query: "Test")

        // Then - Search is performed on enabled sources only
        #expect(mockSourceManager.searchCallCount == 0)
    }

    @Test("search with multiple sources searches all enabled")
    func search_withMultipleSources_searchesAllEnabled() async {
        let mockSourceManager = MockSourceManager()
        let sut = SearchViewModel(sourceManager: mockSourceManager, debounceMilliseconds: 0)

        // Given
        let source1 = TestFixtures.makeInstalledSource(id: "source1", isEnabled: true)
        let source2 = TestFixtures.makeInstalledSource(id: "source2", isEnabled: true)
        let source3 = TestFixtures.makeInstalledSource(id: "source3", isEnabled: false)
        mockSourceManager.installedSources = [source1, source2, source3]
        mockSourceManager.searchResult = .success([TestFixtures.makeAnimePreview()])

        // When
        await sut.search(query: "Test")

        // Then - Should search in 2 enabled sources
        #expect(mockSourceManager.searchCallCount == 2)
    }

    @Test("search updates query")
    func search_updatesQuery() async {
        let mockSourceManager = MockSourceManager()
        let sut = SearchViewModel(sourceManager: mockSourceManager, debounceMilliseconds: 0)

        // Given
        let source = TestFixtures.makeInstalledSource(isEnabled: true)
        mockSourceManager.installedSources = [source]
        mockSourceManager.searchResult = .success([TestFixtures.makeAnimePreview()])

        // When - Search with different queries
        await sut.search(query: "first")
        await sut.search(query: "second")

        // Then - Both searches should complete
        #expect(mockSourceManager.searchQueries.last == "second")
    }
}
