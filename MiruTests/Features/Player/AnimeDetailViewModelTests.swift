//
//  AnimeDetailViewModelTests.swift
//  MiruTests
//
//  Created by Miru on 24.01.26.
//

import XCTest
@testable import Miru

@MainActor
final class AnimeDetailViewModelTests: XCTestCase {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    var sut: AnimeDetailViewModel!
    var mockSourceManager: MockSourceManager!


    //#################################################################################
    // MARK: - Setup & Teardown
    //#################################################################################

    override func setUp() {
        super.setUp()
        mockSourceManager = MockSourceManager()
        let preview = TestFixtures.makeAnimePreview()
        sut = AnimeDetailViewModel(preview: preview, sourceManager: mockSourceManager)
    }

    override func tearDown() {
        sut = nil
        mockSourceManager = nil
        super.tearDown()
    }


    //#################################################################################
    // MARK: - Initialization Tests
    //#################################################################################

    func test_onInitialization_previewIsSet() {
        XCTAssertEqual(sut.preview.id, "1")
        XCTAssertEqual(sut.preview.title, "Test Anime")
    }

    func test_onInitialization_animeIsNil() {
        XCTAssertNil(sut.anime)
    }

    func test_onInitialization_isLoadingIsFalse() {
        XCTAssertFalse(sut.isLoading)
    }

    func test_onInitialization_errorIsNil() {
        XCTAssertNil(sut.error)
    }

    func test_onInitialization_selectedEpisodeIsNil() {
        XCTAssertNil(sut.selectedEpisode)
    }


    //#################################################################################
    // MARK: - loadDetails Tests
    //#################################################################################

    func test_loadDetails_callsSourceManager() async {
        // Given
        let anime = TestFixtures.makeAnime()
        mockSourceManager.getAnimeDetailsResult = .success(anime)

        // When
        await sut.loadDetails()

        // Then
        XCTAssertEqual(mockSourceManager.getAnimeDetailsCallCount, 1)
    }

    func test_loadDetails_onSuccess_setsAnime() async {
        // Given
        let anime = TestFixtures.makeAnime(title: "Loaded Anime")
        mockSourceManager.getAnimeDetailsResult = .success(anime)

        // When
        await sut.loadDetails()

        // Then
        XCTAssertNotNil(sut.anime)
        XCTAssertEqual(sut.anime?.title, "Loaded Anime")
    }

    func test_loadDetails_onError_setsError() async {
        // Given
        mockSourceManager.getAnimeDetailsResult = .failure(MockError.testError)

        // When
        await sut.loadDetails()

        // Then
        XCTAssertNil(sut.anime)
        XCTAssertNotNil(sut.error)
    }

    func test_loadDetails_whenAlreadyLoaded_doesNotLoadAgain() async {
        // Given
        let anime = TestFixtures.makeAnime()
        mockSourceManager.getAnimeDetailsResult = .success(anime)

        // Load once
        await sut.loadDetails()
        XCTAssertEqual(mockSourceManager.getAnimeDetailsCallCount, 1)

        // When - Try to load again
        await sut.loadDetails()

        // Then - Should not load again
        XCTAssertEqual(mockSourceManager.getAnimeDetailsCallCount, 1)
    }

    func test_loadDetails_whenAlreadyLoading_doesNotLoadAgain() async {
        // Given
        let anime = TestFixtures.makeAnime()
        mockSourceManager.getAnimeDetailsResult = .success(anime)

        // When - Start multiple loads concurrently
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await self.sut.loadDetails()
            }
            group.addTask {
                await self.sut.loadDetails()
            }
        }

        // Then - Should only load once due to guard
        XCTAssertEqual(mockSourceManager.getAnimeDetailsCallCount, 1)
    }


    //#################################################################################
    // MARK: - playEpisode Tests
    //#################################################################################

    func test_playEpisode_setsSelectedEpisode() {
        // Given
        let episode = TestFixtures.makeEpisode(id: "ep1", number: "1")

        // When
        sut.playEpisode(episode)

        // Then
        XCTAssertNotNil(sut.selectedEpisode)
        XCTAssertEqual(sut.selectedEpisode?.id, "ep1")
        XCTAssertEqual(sut.selectedEpisode?.number, "1")
    }
}
