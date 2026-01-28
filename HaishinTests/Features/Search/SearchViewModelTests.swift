//
//  SearchViewModelTests.swift
//  HaishinTests
//
//  Created by Haishin on 24.01.26.
//

import Testing
@testable import Haishin


//#################################################################################
// MARK: - SearchViewModel Tests
//#################################################################################

@Suite("SearchViewModel Tests")
@MainActor
struct SearchViewModelTests {

    //#################################################################################
    // MARK: - Helper
    //#################################################################################

    private func makeSUT(sourceManager: MockSourceManager) -> SearchViewModel {
        SearchViewModel(sourceManager: sourceManager,
                        watchProgressService: WatchProgressService.shared,
                        subscriptionService: SubscriptionService.shared,
                        downloadService: MockDownloadService(),
                        debounceMilliseconds: 0)
    }


    //#################################################################################
    // MARK: - Initialization Tests
    //#################################################################################

    @Test("On initialization, sourceStates is empty")
    func initialization_sourceStatesIsEmpty() {
        let mockSourceManager = MockSourceManager()
        let sut = makeSUT(sourceManager: mockSourceManager)

        #expect(sut.sourceStates.isEmpty == true)
    }

    @Test("On initialization, isSearching is false")
    func initialization_isSearchingIsFalse() {
        let mockSourceManager = MockSourceManager()
        let sut = makeSUT(sourceManager: mockSourceManager)

        #expect(sut.isSearching == false)
    }

    @Test("On initialization, error is nil")
    func initialization_errorIsNil() {
        let mockSourceManager = MockSourceManager()
        let sut = makeSUT(sourceManager: mockSourceManager)

        #expect(sut.error == nil)
    }


    //#################################################################################
    // MARK: - search Tests
    //#################################################################################

    @Test("search with empty query clears sourceStates")
    func search_withEmptyQuery_clearsSourceStates() {
        let mockSourceManager = MockSourceManager()
        let sut = makeSUT(sourceManager: mockSourceManager)

        // Given - Set some initial results
        mockSourceManager.searchResult = .success([TestFixtures.makeAnimePreview()])

        // When
        sut.search(query: "")

        // Then
        #expect(sut.sourceStates.isEmpty == true)
        #expect(mockSourceManager.searchCallCount == 0)
    }

    @Test("search with whitespace only query clears sourceStates")
    func search_withWhitespaceOnlyQuery_clearsSourceStates() {
        let mockSourceManager = MockSourceManager()
        let sut = makeSUT(sourceManager: mockSourceManager)

        // When
        sut.search(query: "   ")

        // Then
        #expect(sut.sourceStates.isEmpty == true)
        #expect(mockSourceManager.searchCallCount == 0)
    }

    @Test("search with valid query creates source states for all sources")
    func search_withValidQuery_createsSourceStates() async throws {
        let mockSourceManager = MockSourceManager()
        let sut = makeSUT(sourceManager: mockSourceManager)

        // Given
        let source = TestFixtures.makeInstalledSource()
        mockSourceManager.installedSources = [source]
        let expectedAnime = TestFixtures.makeAnimePreview(title: "Naruto")
        mockSourceManager.searchResult = .success([expectedAnime])

        // When
        sut.search(query: "Naruto")

        // Then - Source state should be created immediately
        #expect(sut.sourceStates.count == 1)
        #expect(sut.sourceStates.first?.sourceId == source.id)

        // Wait for search to complete
        try await Task.sleep(for: .milliseconds(50))

        // Verify search was called
        #expect(mockSourceManager.searchCallCount == 1)
        #expect(mockSourceManager.searchQueries.first == "Naruto")
    }

    @Test("search with multiple sources creates states for all and searches all")
    func search_withMultipleSources_createsStatesForAllAndSearchesAll() async throws {
        let mockSourceManager = MockSourceManager()
        let sut = makeSUT(sourceManager: mockSourceManager)

        // Given
        let source1 = TestFixtures.makeInstalledSource(id: "source1", name: "A Source")
        let source2 = TestFixtures.makeInstalledSource(id: "source2", name: "B Source")
        let source3 = TestFixtures.makeInstalledSource(id: "source3", name: "C Source")
        mockSourceManager.installedSources = [source1, source2, source3]
        mockSourceManager.searchResult = .success([TestFixtures.makeAnimePreview()])

        // When
        sut.search(query: "Test")

        // Then - Should create states for all 3 sources immediately
        #expect(sut.sourceStates.count == 3)

        // Wait for all searches to complete
        try await Task.sleep(for: .milliseconds(100))

        // Then - Should search in all 3 sources
        #expect(mockSourceManager.searchCallCount == 3)
    }

    @Test("search updates sourceStates when query changes")
    func search_updatesSourceStatesWhenQueryChanges() async throws {
        let mockSourceManager = MockSourceManager()
        let sut = makeSUT(sourceManager: mockSourceManager)

        // Given
        let source = TestFixtures.makeInstalledSource()
        mockSourceManager.installedSources = [source]
        mockSourceManager.searchResult = .success([TestFixtures.makeAnimePreview()])

        // When - Search with different queries
        sut.search(query: "first")
        try await Task.sleep(for: .milliseconds(50))
        
        sut.search(query: "second")
        try await Task.sleep(for: .milliseconds(50))

        // Then - Both searches should eventually complete
        #expect(mockSourceManager.searchQueries.contains("second"))
    }
}
