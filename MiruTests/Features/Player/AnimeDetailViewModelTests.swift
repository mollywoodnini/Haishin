//
//  AnimeDetailViewModelTests.swift
//  MiruTests
//
//  Created by Miru on 24.01.26.
//

import Testing
@testable import Miru


//#################################################################################
// MARK: - AnimeDetailViewModel Tests
//#################################################################################

@Suite("AnimeDetailViewModel Tests")
@MainActor
struct AnimeDetailViewModelTests {

    //#################################################################################
    // MARK: - Initialization Tests
    //#################################################################################

    @Test("On initialization, preview is set")
    func initialization_previewIsSet() {
        let mockSourceManager = MockSourceManager()
        let preview = TestFixtures.makeAnimePreview()
        let sut = AnimeDetailViewModel(preview: preview, sourceManager: mockSourceManager)

        #expect(sut.preview.id == "1")
        #expect(sut.preview.title == "Test Anime")
    }

    @Test("On initialization, anime is nil")
    func initialization_animeIsNil() {
        let mockSourceManager = MockSourceManager()
        let preview = TestFixtures.makeAnimePreview()
        let sut = AnimeDetailViewModel(preview: preview, sourceManager: mockSourceManager)

        #expect(sut.anime == nil)
    }

    @Test("On initialization, isLoading is false")
    func initialization_isLoadingIsFalse() {
        let mockSourceManager = MockSourceManager()
        let preview = TestFixtures.makeAnimePreview()
        let sut = AnimeDetailViewModel(preview: preview, sourceManager: mockSourceManager)

        #expect(sut.isLoading == false)
    }

    @Test("On initialization, error is nil")
    func initialization_errorIsNil() {
        let mockSourceManager = MockSourceManager()
        let preview = TestFixtures.makeAnimePreview()
        let sut = AnimeDetailViewModel(preview: preview, sourceManager: mockSourceManager)

        #expect(sut.error == nil)
    }

    @Test("On initialization, selectedEpisode is nil")
    func initialization_selectedEpisodeIsNil() {
        let mockSourceManager = MockSourceManager()
        let preview = TestFixtures.makeAnimePreview()
        let sut = AnimeDetailViewModel(preview: preview, sourceManager: mockSourceManager)

        #expect(sut.selectedEpisode == nil)
    }


    //#################################################################################
    // MARK: - loadDetails Tests
    //#################################################################################

    @Test("loadDetails calls source manager")
    func loadDetails_callsSourceManager() async {
        let mockSourceManager = MockSourceManager()
        let preview = TestFixtures.makeAnimePreview()
        let sut = AnimeDetailViewModel(preview: preview, sourceManager: mockSourceManager)

        // Given
        let anime = TestFixtures.makeAnime()
        mockSourceManager.getAnimeDetailsResult = .success(anime)

        // When
        await sut.loadDetails()

        // Then
        #expect(mockSourceManager.getAnimeDetailsCallCount == 1)
    }

    @Test("loadDetails on success sets anime")
    func loadDetails_onSuccess_setsAnime() async {
        let mockSourceManager = MockSourceManager()
        let preview = TestFixtures.makeAnimePreview()
        let sut = AnimeDetailViewModel(preview: preview, sourceManager: mockSourceManager)

        // Given
        let anime = TestFixtures.makeAnime(title: "Loaded Anime")
        mockSourceManager.getAnimeDetailsResult = .success(anime)

        // When
        await sut.loadDetails()

        // Then
        #expect(sut.anime != nil)
        #expect(sut.anime?.title == "Loaded Anime")
    }

    @Test("loadDetails on error sets error")
    func loadDetails_onError_setsError() async {
        let mockSourceManager = MockSourceManager()
        let preview = TestFixtures.makeAnimePreview()
        let sut = AnimeDetailViewModel(preview: preview, sourceManager: mockSourceManager)

        // Given
        mockSourceManager.getAnimeDetailsResult = .failure(MockError.testError)

        // When
        await sut.loadDetails()

        // Then
        #expect(sut.anime == nil)
        #expect(sut.error != nil)
    }

    @Test("loadDetails when already loaded does not load again")
    func loadDetails_whenAlreadyLoaded_doesNotLoadAgain() async {
        let mockSourceManager = MockSourceManager()
        let preview = TestFixtures.makeAnimePreview()
        let sut = AnimeDetailViewModel(preview: preview, sourceManager: mockSourceManager)

        // Given
        let anime = TestFixtures.makeAnime()
        mockSourceManager.getAnimeDetailsResult = .success(anime)

        // Load once
        await sut.loadDetails()
        #expect(mockSourceManager.getAnimeDetailsCallCount == 1)

        // When - Try to load again
        await sut.loadDetails()

        // Then - Should not load again
        #expect(mockSourceManager.getAnimeDetailsCallCount == 1)
    }

    @Test("loadDetails when already loading does not load again")
    func loadDetails_whenAlreadyLoading_doesNotLoadAgain() async {
        let mockSourceManager = MockSourceManager()
        let preview = TestFixtures.makeAnimePreview()
        let sut = AnimeDetailViewModel(preview: preview, sourceManager: mockSourceManager)

        // Given
        let anime = TestFixtures.makeAnime()
        mockSourceManager.getAnimeDetailsResult = .success(anime)

        // When - Start multiple loads concurrently
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await sut.loadDetails()
            }
            group.addTask {
                await sut.loadDetails()
            }
        }

        // Then - Should only load once due to guard
        #expect(mockSourceManager.getAnimeDetailsCallCount == 1)
    }


    //#################################################################################
    // MARK: - playEpisode Tests
    //#################################################################################

    @Test("playEpisode sets selectedEpisode")
    func playEpisode_setsSelectedEpisode() {
        let mockSourceManager = MockSourceManager()
        let preview = TestFixtures.makeAnimePreview()
        let sut = AnimeDetailViewModel(preview: preview, sourceManager: mockSourceManager)

        // Given
        let episode = TestFixtures.makeEpisode(id: "ep1", number: "1")

        // When
        sut.playEpisode(episode)

        // Then
        #expect(sut.selectedEpisode != nil)
        #expect(sut.selectedEpisode?.id == "ep1")
        #expect(sut.selectedEpisode?.number == "1")
    }
}
