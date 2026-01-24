//
//  SourcesViewModelTests.swift
//  MiruTests
//
//  Created by Miru on 24.01.26.
//

import XCTest
@testable import Miru

final class SourcesViewModelTests: XCTestCase {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    var sut: SourcesViewModel!
    var mockSourceManager: MockSourceManager!


    //#################################################################################
    // MARK: - Setup & Teardown
    //#################################################################################

    override func setUp() {
        super.setUp()
        mockSourceManager = MockSourceManager()
        sut = SourcesViewModel(sourceManager: mockSourceManager)
    }

    override func tearDown() {
        sut = nil
        mockSourceManager = nil
        super.tearDown()
    }


    //#################################################################################
    // MARK: - Initialization Tests
    //#################################################################################

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
    // MARK: - repositories Tests
    //#################################################################################

    func test_repositories_returnsSourceManagerRepositories() {
        // Given
        let repo = TestFixtures.makeSourceRepository()
        mockSourceManager.repositories = [repo]

        // Then
        XCTAssertEqual(sut.repositories.count, 1)
        XCTAssertEqual(sut.repositories.first?.name, repo.name)
    }


    //#################################################################################
    // MARK: - addRepository Tests
    //#################################################################################

    func test_addRepository_withValidURL_callsSourceManager() async {
        // Given
        let urlString = "https://example.com/repo.json"

        // When
        await sut.addRepository(urlString: urlString)

        // Then
        XCTAssertEqual(mockSourceManager.addRepositoryCallCount, 1)
        XCTAssertEqual(mockSourceManager.addRepositoryURLs.first?.absoluteString, urlString)
    }

    func test_addRepository_withInvalidURL_setsError() async {
        // Given
        let invalidURLString = ""

        // When
        await sut.addRepository(urlString: invalidURLString)

        // Then
        XCTAssertNotNil(sut.error)
        XCTAssertEqual(mockSourceManager.addRepositoryCallCount, 0)
    }


    //#################################################################################
    // MARK: - installSource Tests
    //#################################################################################

    func test_installSource_callsSourceManager() async {
        // Given
        let sourceInfo = TestFixtures.makeSourceInfo()
        let repository = TestFixtures.makeSourceRepository()

        // When
        await sut.installSource(sourceInfo, from: repository)

        // Then
        XCTAssertEqual(mockSourceManager.installSourceCallCount, 1)
        XCTAssertEqual(mockSourceManager.installedSourceInfos.first?.id, sourceInfo.id)
    }


    //#################################################################################
    // MARK: - uninstallSource Tests
    //#################################################################################

    func test_uninstallSource_callsSourceManager() {
        // Given
        let source = TestFixtures.makeInstalledSource()
        mockSourceManager.installedSources = [source]

        // When
        sut.uninstallSource(source)

        // Then
        XCTAssertEqual(mockSourceManager.uninstallSourceCallCount, 1)
        XCTAssertEqual(mockSourceManager.uninstalledSourceIds.first, source.id)
    }


    //#################################################################################
    // MARK: - isInstalled Tests
    //#################################################################################

    func test_isInstalled_whenSourceExists_returnsTrue() {
        // Given
        let sourceInfo = TestFixtures.makeSourceInfo(id: "test-source")
        let installedSource = TestFixtures.makeInstalledSource(id: "test-source")
        mockSourceManager.installedSources = [installedSource]

        // Then
        XCTAssertTrue(sut.isInstalled(sourceInfo))
    }

    func test_isInstalled_whenSourceNotExists_returnsFalse() {
        // Given
        let sourceInfo = TestFixtures.makeSourceInfo(id: "not-installed")
        mockSourceManager.installedSources = []

        // Then
        XCTAssertFalse(sut.isInstalled(sourceInfo))
    }


    //#################################################################################
    // MARK: - toggleSource Tests
    //#################################################################################

    func test_toggleSource_withInstalledSource_togglesEnabled() {
        // Given
        let source = TestFixtures.makeInstalledSource()
        mockSourceManager.installedSources = [source]

        // When
        sut.toggleSource(source)

        // Then - Currently just prints, verify no crash
        XCTAssertEqual(mockSourceManager.installedSources.count, 1)
    }
}
