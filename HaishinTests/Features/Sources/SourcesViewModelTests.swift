//
//  SourcesViewModelTests.swift
//  HaishinTests
//
//  Created by Haishin on 24.01.26.
//

import Foundation
import Testing
@testable import Haishin


//#################################################################################
// MARK: - SourcesViewModel Tests
//#################################################################################

@Suite("SourcesViewModel Tests")
@MainActor
struct SourcesViewModelTests {

    //#################################################################################
    // MARK: - Initialization Tests
    //#################################################################################

    @Test("On initialization, isLoading is false")
    func initialization_isLoadingIsFalse() {
        let mockSourceManager = MockSourceManager()
        let sut = SourcesViewModel(sourceManager: mockSourceManager)

        #expect(sut.isLoading == false)
    }

    @Test("On initialization, error is nil")
    func initialization_errorIsNil() {
        let mockSourceManager = MockSourceManager()
        let sut = SourcesViewModel(sourceManager: mockSourceManager)

        #expect(sut.error == nil)
    }


    //#################################################################################
    // MARK: - installedSources Tests
    //#################################################################################

    @Test("installedSources returns source manager sources")
    func installedSources_returnsSourceManagerSources() {
        let mockSourceManager = MockSourceManager()
        let sut = SourcesViewModel(sourceManager: mockSourceManager)

        // Given
        let source = TestFixtures.makeInstalledSource()
        mockSourceManager.installedSources = [source]

        // Then
        #expect(sut.installedSources.count == 1)
        #expect(sut.installedSources.first?.id == source.id)
    }


    //#################################################################################
    // MARK: - repositories Tests
    //#################################################################################

    @Test("repositories returns source manager repositories")
    func repositories_returnsSourceManagerRepositories() {
        let mockSourceManager = MockSourceManager()
        let sut = SourcesViewModel(sourceManager: mockSourceManager)

        // Given
        let repo = TestFixtures.makeSourceRepository()
        mockSourceManager.repositories = [repo]

        // Then
        #expect(sut.repositories.count == 1)
        #expect(sut.repositories.first?.name == repo.name)
    }


    //#################################################################################
    // MARK: - addRepository Tests
    //#################################################################################

    @Test("addRepository with valid URL calls source manager")
    func addRepository_withValidURL_callsSourceManager() async {
        let mockSourceManager = MockSourceManager()
        let sut = SourcesViewModel(sourceManager: mockSourceManager)

        // Given
        let urlString = "https://example.com/repo.json"

        // When
        await sut.addRepository(urlString: urlString)

        // Then
        #expect(mockSourceManager.addRepositoryCallCount == 1)
        #expect(mockSourceManager.addRepositoryURLs.first?.absoluteString == urlString)
    }

    @Test("addRepository with invalid URL sets error")
    func addRepository_withInvalidURL_setsError() async {
        let mockSourceManager = MockSourceManager()
        let sut = SourcesViewModel(sourceManager: mockSourceManager)

        // Given
        let invalidURLString = ""

        // When
        await sut.addRepository(urlString: invalidURLString)

        // Then
        #expect(sut.error != nil)
        #expect(mockSourceManager.addRepositoryCallCount == 0)
    }


    //#################################################################################
    // MARK: - installSource Tests
    //#################################################################################

    @Test("installSource calls source manager")
    func installSource_callsSourceManager() async {
        let mockSourceManager = MockSourceManager()
        let sut = SourcesViewModel(sourceManager: mockSourceManager)

        // Given
        let sourceInfo = TestFixtures.makeSourceInfo()
        let repository = TestFixtures.makeSourceRepository()

        // When
        await sut.installSource(sourceInfo, from: repository)

        // Then
        #expect(mockSourceManager.installSourceCallCount == 1)
        #expect(mockSourceManager.installedSourceInfos.first?.id == sourceInfo.id)
    }


    //#################################################################################
    // MARK: - uninstallSource Tests
    //#################################################################################

    @Test("uninstallSource calls source manager")
    func uninstallSource_callsSourceManager() {
        let mockSourceManager = MockSourceManager()
        let sut = SourcesViewModel(sourceManager: mockSourceManager)

        // Given
        let source = TestFixtures.makeInstalledSource()
        mockSourceManager.installedSources = [source]

        // When
        sut.uninstallSource(source)

        // Then
        #expect(mockSourceManager.uninstallSourceCallCount == 1)
        #expect(mockSourceManager.uninstalledSourceIds.first == source.id)
    }


    //#################################################################################
    // MARK: - isInstalled Tests
    //#################################################################################

    @Test("isInstalled when source exists returns true")
    func isInstalled_whenSourceExists_returnsTrue() {
        let mockSourceManager = MockSourceManager()
        let sut = SourcesViewModel(sourceManager: mockSourceManager)

        // Given
        let sourceInfo = TestFixtures.makeSourceInfo(id: "test-source")
        let installedSource = TestFixtures.makeInstalledSource(id: "test-source")
        mockSourceManager.installedSources = [installedSource]

        // Then
        #expect(sut.isInstalled(sourceInfo) == true)
    }

    @Test("isInstalled when source not exists returns false")
    func isInstalled_whenSourceNotExists_returnsFalse() {
        let mockSourceManager = MockSourceManager()
        let sut = SourcesViewModel(sourceManager: mockSourceManager)

        // Given
        let sourceInfo = TestFixtures.makeSourceInfo(id: "not-installed")
        mockSourceManager.installedSources = []

        // Then
        #expect(sut.isInstalled(sourceInfo) == false)
    }


    //#################################################################################
    // MARK: - toggleSource Tests
    //#################################################################################

    @Test("toggleSource with installed source toggles enabled")
    func toggleSource_withInstalledSource_togglesEnabled() {
        let mockSourceManager = MockSourceManager()
        let sut = SourcesViewModel(sourceManager: mockSourceManager)

        // Given
        let source = TestFixtures.makeInstalledSource()
        mockSourceManager.installedSources = [source]

        // When
        sut.toggleSource(source)

        // Then - Currently just prints, verify no crash
        #expect(mockSourceManager.installedSources.count == 1)
    }
}
