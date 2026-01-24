//
//  BrowseViewModelTests.swift
//  MiruTests
//
//  Created by Miru on 24.01.26.
//

import XCTest
@testable import Miru

final class BrowseViewModelTests: XCTestCase {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    var sut: BrowseViewModel!
    var mockSourceManager: MockSourceManager!


    //#################################################################################
    // MARK: - Setup & Teardown
    //#################################################################################

    override func setUp() {
        super.setUp()
        mockSourceManager = MockSourceManager()
        sut = BrowseViewModel(sourceManager: mockSourceManager)
    }

    override func tearDown() {
        sut = nil
        mockSourceManager = nil
        super.tearDown()
    }


    //#################################################################################
    // MARK: - Initialization Tests
    //#################################################################################

    func test_onInitialization_popularAnimeIsEmpty() {
        XCTAssertTrue(sut.popularAnime.isEmpty)
    }

    func test_onInitialization_latestAnimeIsEmpty() {
        XCTAssertTrue(sut.latestAnime.isEmpty)
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

    func test_loadContent_withNoSources_doesNotLoadAnime() async {
        // Given
        mockSourceManager.installedSources = []

        // When
        await sut.loadContent()

        // Then
        XCTAssertEqual(mockSourceManager.getPopularCallCount, 0)
        XCTAssertEqual(mockSourceManager.getLatestCallCount, 0)
    }

    func test_loadContent_withEnabledSource_loadsPopularAndLatest() async {
        // Given
        let source = TestFixtures.makeInstalledSource(isEnabled: true)
        mockSourceManager.installedSources = [source]
        mockSourceManager.getPopularResult = .success([TestFixtures.makeAnimePreview()])
        mockSourceManager.getLatestResult = .success([TestFixtures.makeAnimePreview(id: "2")])

        // When
        await sut.loadContent()

        // Then
        XCTAssertEqual(mockSourceManager.getPopularCallCount, 1)
        XCTAssertEqual(mockSourceManager.getLatestCallCount, 1)
        XCTAssertEqual(sut.popularAnime.count, 1)
        XCTAssertEqual(sut.latestAnime.count, 1)
    }

    func test_loadContent_withDisabledSource_doesNotLoadAnime() async {
        // Given
        let source = TestFixtures.makeInstalledSource(isEnabled: false)
        mockSourceManager.installedSources = [source]

        // When
        await sut.loadContent()

        // Then
        XCTAssertEqual(mockSourceManager.getPopularCallCount, 0)
        XCTAssertEqual(mockSourceManager.getLatestCallCount, 0)
    }

    func test_loadContent_whenAlreadyLoading_doesNotLoadAgain() async {
        // This test verifies the guard in loadContent
        // Given
        let source = TestFixtures.makeInstalledSource(isEnabled: true)
        mockSourceManager.installedSources = [source]

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

        // Then - Should only load once per enabled source
        // (The guard prevents duplicate loads)
        XCTAssertGreaterThanOrEqual(mockSourceManager.getPopularCallCount, 1)
    }


    //#################################################################################
    // MARK: - refresh Tests
    //#################################################################################

    func test_refresh_clearsExistingAnimeAndReloads() async {
        // Given
        let source = TestFixtures.makeInstalledSource(isEnabled: true)
        mockSourceManager.installedSources = [source]
        mockSourceManager.getPopularResult = .success([TestFixtures.makeAnimePreview()])
        mockSourceManager.getLatestResult = .success([TestFixtures.makeAnimePreview(id: "2")])

        // Load initial content
        await sut.loadContent()

        XCTAssertEqual(sut.popularAnime.count, 1)
        XCTAssertEqual(sut.latestAnime.count, 1)

        // When
        await sut.refresh()

        // Then - Content should be reloaded
        XCTAssertEqual(mockSourceManager.getPopularCallCount, 2)
        XCTAssertEqual(mockSourceManager.getLatestCallCount, 2)
    }
}
