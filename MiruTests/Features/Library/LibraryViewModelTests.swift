//
//  LibraryViewModelTests.swift
//  MiruTests
//
//  Created by Miru on 24.01.26.
//

import XCTest
@testable import Miru

final class LibraryViewModelTests: XCTestCase {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    var sut: LibraryViewModel!


    //#################################################################################
    // MARK: - Setup & Teardown
    //#################################################################################

    override func setUp() {
        super.setUp()
        // Clear UserDefaults before each test
        UserDefaults.standard.removeObject(forKey: "libraryItems")
        sut = LibraryViewModel()
    }

    override func tearDown() {
        sut = nil
        // Clean up UserDefaults after each test
        UserDefaults.standard.removeObject(forKey: "libraryItems")
        super.tearDown()
    }


    //#################################################################################
    // MARK: - Initialization Tests
    //#################################################################################

    func test_onInitialization_itemsIsEmpty() {
        XCTAssertTrue(sut.items.isEmpty)
    }


    //#################################################################################
    // MARK: - addToLibrary Tests
    //#################################################################################

    func test_addToLibrary_addsAnimeToItems() {
        // Given
        let anime = TestFixtures.makeAnimePreview()

        // When
        sut.addToLibrary(anime: anime)

        // Then
        XCTAssertEqual(sut.items.count, 1)
        XCTAssertEqual(sut.items.first?.anime.id, anime.id)
    }

    func test_addToLibrary_withCategory_setsCorrectCategory() {
        // Given
        let anime = TestFixtures.makeAnimePreview()

        // When
        sut.addToLibrary(anime: anime, category: .completed)

        // Then
        XCTAssertEqual(sut.items.first?.category, .completed)
    }

    func test_addToLibrary_withDefaultCategory_setsPlanToWatch() {
        // Given
        let anime = TestFixtures.makeAnimePreview()

        // When
        sut.addToLibrary(anime: anime)

        // Then
        XCTAssertEqual(sut.items.first?.category, .planToWatch)
    }

    func test_addToLibrary_withDuplicate_doesNotAdd() {
        // Given
        let anime = TestFixtures.makeAnimePreview()

        // When
        sut.addToLibrary(anime: anime)
        sut.addToLibrary(anime: anime)

        // Then
        XCTAssertEqual(sut.items.count, 1)
    }

    func test_addToLibrary_withDifferentSource_addsAnime() {
        // Given
        let anime1 = TestFixtures.makeAnimePreview(id: "1", sourceId: "source1")
        let anime2 = TestFixtures.makeAnimePreview(id: "1", sourceId: "source2")

        // When
        sut.addToLibrary(anime: anime1)
        sut.addToLibrary(anime: anime2)

        // Then
        XCTAssertEqual(sut.items.count, 2)
    }


    //#################################################################################
    // MARK: - filteredItems Tests
    //#################################################################################

    func test_filteredItems_returnsCorrectCategory() {
        // Given
        let anime1 = TestFixtures.makeAnimePreview(id: "1")
        let anime2 = TestFixtures.makeAnimePreview(id: "2")
        let anime3 = TestFixtures.makeAnimePreview(id: "3")

        sut.addToLibrary(anime: anime1, category: .watching)
        sut.addToLibrary(anime: anime2, category: .watching)
        sut.addToLibrary(anime: anime3, category: .completed)

        // When
        let watchingItems = sut.filteredItems(for: .watching)
        let completedItems = sut.filteredItems(for: .completed)

        // Then
        XCTAssertEqual(watchingItems.count, 2)
        XCTAssertEqual(completedItems.count, 1)
    }

    func test_filteredItems_withNoMatchingItems_returnsEmpty() {
        // Given
        let anime = TestFixtures.makeAnimePreview()
        sut.addToLibrary(anime: anime, category: .watching)

        // When
        let droppedItems = sut.filteredItems(for: .dropped)

        // Then
        XCTAssertTrue(droppedItems.isEmpty)
    }


    //#################################################################################
    // MARK: - updateCategory Tests
    //#################################################################################

    func test_updateCategory_updatesItemCategory() {
        // Given
        let anime = TestFixtures.makeAnimePreview()
        sut.addToLibrary(anime: anime, category: .watching)
        let item = sut.items.first!

        // When
        sut.updateCategory(item: item, to: .completed)

        // Then
        XCTAssertEqual(sut.items.first?.category, .completed)
    }

    func test_updateCategory_withNonExistentItem_doesNothing() {
        // Given
        let anime = TestFixtures.makeAnimePreview()
        sut.addToLibrary(anime: anime, category: .watching)

        // Create a fake item that doesn't exist
        let fakeItem = TestFixtures.makeLibraryItem()

        // When
        sut.updateCategory(item: fakeItem, to: .completed)

        // Then - Original item unchanged
        XCTAssertEqual(sut.items.first?.category, .watching)
    }


    //#################################################################################
    // MARK: - updateProgress Tests
    //#################################################################################

    func test_updateProgress_updatesEpisodeAndProgress() {
        // Given
        let anime = TestFixtures.makeAnimePreview()
        sut.addToLibrary(anime: anime, category: .watching)
        let item = sut.items.first!

        // When
        sut.updateProgress(item: item, episode: "5", progress: 0.75)

        // Then
        XCTAssertEqual(sut.items.first?.lastWatchedEpisode, "5")
        XCTAssertEqual(sut.items.first?.lastWatchedProgress, 0.75)
        XCTAssertNotNil(sut.items.first?.lastWatchedAt)
    }

    func test_updateProgress_movesFromPlanToWatchToWatching() {
        // Given
        let anime = TestFixtures.makeAnimePreview()
        sut.addToLibrary(anime: anime, category: .planToWatch)
        let item = sut.items.first!
        XCTAssertEqual(sut.items.first?.category, .planToWatch)

        // When
        sut.updateProgress(item: item, episode: "1", progress: 0.5)

        // Then
        XCTAssertEqual(sut.items.first?.category, .watching)
    }

    func test_updateProgress_doesNotChangeOtherCategories() {
        // Given
        let anime = TestFixtures.makeAnimePreview()
        sut.addToLibrary(anime: anime, category: .completed)
        let item = sut.items.first!

        // When
        sut.updateProgress(item: item, episode: "1", progress: 0.5)

        // Then - Should stay completed
        XCTAssertEqual(sut.items.first?.category, .completed)
    }


    //#################################################################################
    // MARK: - removeFromLibrary Tests
    //#################################################################################

    func test_removeFromLibrary_removesItem() {
        // Given
        let anime = TestFixtures.makeAnimePreview()
        sut.addToLibrary(anime: anime)
        let item = sut.items.first!
        XCTAssertEqual(sut.items.count, 1)

        // When
        sut.removeFromLibrary(item: item)

        // Then
        XCTAssertTrue(sut.items.isEmpty)
    }


    //#################################################################################
    // MARK: - deleteItems Tests
    //#################################################################################

    func test_deleteItems_removesItemsAtIndices() {
        // Given
        let anime1 = TestFixtures.makeAnimePreview(id: "1")
        let anime2 = TestFixtures.makeAnimePreview(id: "2")
        let anime3 = TestFixtures.makeAnimePreview(id: "3")

        sut.addToLibrary(anime: anime1, category: .watching)
        sut.addToLibrary(anime: anime2, category: .watching)
        sut.addToLibrary(anime: anime3, category: .watching)

        // When - Delete first item
        sut.deleteItems(at: IndexSet(integer: 0), in: .watching)

        // Then
        XCTAssertEqual(sut.items.count, 2)
    }


    //#################################################################################
    // MARK: - Persistence Tests
    //#################################################################################

    func test_persistence_savesAndLoadsItems() {
        // Given
        let anime = TestFixtures.makeAnimePreview()
        sut.addToLibrary(anime: anime)

        // When - Create new instance (simulates app restart)
        let newSut = LibraryViewModel()

        // Then
        XCTAssertEqual(newSut.items.count, 1)
        XCTAssertEqual(newSut.items.first?.anime.id, anime.id)
    }
}
