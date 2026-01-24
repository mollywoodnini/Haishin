//
//  LibraryViewModelTests.swift
//  MiruTests
//
//  Created by Miru on 24.01.26.
//

import Testing
import Foundation
@testable import Miru


//#################################################################################
// MARK: - LibraryViewModel Tests
//#################################################################################

@Suite("LibraryViewModel Tests")
@MainActor
struct LibraryViewModelTests {

    //#################################################################################
    // MARK: - Helper
    //#################################################################################

    /// Creates a fresh LibraryViewModel with cleared UserDefaults.
    private func makeSUT() -> LibraryViewModel {
        UserDefaults.standard.removeObject(forKey: "libraryItems")
        return LibraryViewModel()
    }


    //#################################################################################
    // MARK: - Initialization Tests
    //#################################################################################

    @Test("On initialization, items is empty")
    func initialization_itemsIsEmpty() {
        let sut = makeSUT()

        #expect(sut.items.isEmpty == true)
    }


    //#################################################################################
    // MARK: - addToLibrary Tests
    //#################################################################################

    @Test("addToLibrary adds anime to items")
    func addToLibrary_addsAnimeToItems() {
        let sut = makeSUT()
        let anime = TestFixtures.makeAnimePreview()

        sut.addToLibrary(anime: anime)

        #expect(sut.items.count == 1)
        #expect(sut.items.first?.anime.id == anime.id)
    }

    @Test("addToLibrary with category sets correct category")
    func addToLibrary_withCategory_setsCorrectCategory() {
        let sut = makeSUT()
        let anime = TestFixtures.makeAnimePreview()

        sut.addToLibrary(anime: anime, category: .completed)

        #expect(sut.items.first?.category == .completed)
    }

    @Test("addToLibrary with default category sets planToWatch")
    func addToLibrary_withDefaultCategory_setsPlanToWatch() {
        let sut = makeSUT()
        let anime = TestFixtures.makeAnimePreview()

        sut.addToLibrary(anime: anime)

        #expect(sut.items.first?.category == .planToWatch)
    }

    @Test("addToLibrary with duplicate does not add")
    func addToLibrary_withDuplicate_doesNotAdd() {
        let sut = makeSUT()
        let anime = TestFixtures.makeAnimePreview()

        sut.addToLibrary(anime: anime)
        sut.addToLibrary(anime: anime)

        #expect(sut.items.count == 1)
    }

    @Test("addToLibrary with different source adds anime")
    func addToLibrary_withDifferentSource_addsAnime() {
        let sut = makeSUT()
        let anime1 = TestFixtures.makeAnimePreview(id: "1", sourceId: "source1")
        let anime2 = TestFixtures.makeAnimePreview(id: "1", sourceId: "source2")

        sut.addToLibrary(anime: anime1)
        sut.addToLibrary(anime: anime2)

        #expect(sut.items.count == 2)
    }


    //#################################################################################
    // MARK: - filteredItems Tests
    //#################################################################################

    @Test("filteredItems returns correct category")
    func filteredItems_returnsCorrectCategory() {
        let sut = makeSUT()
        let anime1 = TestFixtures.makeAnimePreview(id: "1")
        let anime2 = TestFixtures.makeAnimePreview(id: "2")
        let anime3 = TestFixtures.makeAnimePreview(id: "3")

        sut.addToLibrary(anime: anime1, category: .watching)
        sut.addToLibrary(anime: anime2, category: .watching)
        sut.addToLibrary(anime: anime3, category: .completed)

        let watchingItems = sut.filteredItems(for: .watching)
        let completedItems = sut.filteredItems(for: .completed)

        #expect(watchingItems.count == 2)
        #expect(completedItems.count == 1)
    }

    @Test("filteredItems with no matching items returns empty")
    func filteredItems_withNoMatchingItems_returnsEmpty() {
        let sut = makeSUT()
        let anime = TestFixtures.makeAnimePreview()
        sut.addToLibrary(anime: anime, category: .watching)

        let droppedItems = sut.filteredItems(for: .dropped)

        #expect(droppedItems.isEmpty == true)
    }


    //#################################################################################
    // MARK: - updateCategory Tests
    //#################################################################################

    @Test("updateCategory updates item category")
    func updateCategory_updatesItemCategory() {
        let sut = makeSUT()
        let anime = TestFixtures.makeAnimePreview()
        sut.addToLibrary(anime: anime, category: .watching)
        let item = sut.items.first!

        sut.updateCategory(item: item, to: .completed)

        #expect(sut.items.first?.category == .completed)
    }

    @Test("updateCategory with non-existent item does nothing")
    func updateCategory_withNonExistentItem_doesNothing() {
        let sut = makeSUT()
        let anime = TestFixtures.makeAnimePreview()
        sut.addToLibrary(anime: anime, category: .watching)

        // Create a fake item that doesn't exist
        let fakeItem = TestFixtures.makeLibraryItem()

        sut.updateCategory(item: fakeItem, to: .completed)

        // Original item unchanged
        #expect(sut.items.first?.category == .watching)
    }


    //#################################################################################
    // MARK: - updateProgress Tests
    //#################################################################################

    @Test("updateProgress updates episode and progress")
    func updateProgress_updatesEpisodeAndProgress() {
        let sut = makeSUT()
        let anime = TestFixtures.makeAnimePreview()
        sut.addToLibrary(anime: anime, category: .watching)
        let item = sut.items.first!

        sut.updateProgress(item: item, episode: "5", progress: 0.75)

        #expect(sut.items.first?.lastWatchedEpisode == "5")
        #expect(sut.items.first?.lastWatchedProgress == 0.75)
        #expect(sut.items.first?.lastWatchedAt != nil)
    }

    @Test("updateProgress moves from planToWatch to watching")
    func updateProgress_movesFromPlanToWatchToWatching() {
        let sut = makeSUT()
        let anime = TestFixtures.makeAnimePreview()
        sut.addToLibrary(anime: anime, category: .planToWatch)
        let item = sut.items.first!
        #expect(sut.items.first?.category == .planToWatch)

        sut.updateProgress(item: item, episode: "1", progress: 0.5)

        #expect(sut.items.first?.category == .watching)
    }

    @Test("updateProgress does not change other categories")
    func updateProgress_doesNotChangeOtherCategories() {
        let sut = makeSUT()
        let anime = TestFixtures.makeAnimePreview()
        sut.addToLibrary(anime: anime, category: .completed)
        let item = sut.items.first!

        sut.updateProgress(item: item, episode: "1", progress: 0.5)

        // Should stay completed
        #expect(sut.items.first?.category == .completed)
    }


    //#################################################################################
    // MARK: - removeFromLibrary Tests
    //#################################################################################

    @Test("removeFromLibrary removes item")
    func removeFromLibrary_removesItem() {
        let sut = makeSUT()
        let anime = TestFixtures.makeAnimePreview()
        sut.addToLibrary(anime: anime)
        let item = sut.items.first!
        #expect(sut.items.count == 1)

        sut.removeFromLibrary(item: item)

        #expect(sut.items.isEmpty == true)
    }


    //#################################################################################
    // MARK: - deleteItems Tests
    //#################################################################################

    @Test("deleteItems removes items at indices")
    func deleteItems_removesItemsAtIndices() {
        let sut = makeSUT()
        let anime1 = TestFixtures.makeAnimePreview(id: "1")
        let anime2 = TestFixtures.makeAnimePreview(id: "2")
        let anime3 = TestFixtures.makeAnimePreview(id: "3")

        sut.addToLibrary(anime: anime1, category: .watching)
        sut.addToLibrary(anime: anime2, category: .watching)
        sut.addToLibrary(anime: anime3, category: .watching)

        // Delete first item
        sut.deleteItems(at: IndexSet(integer: 0), in: .watching)

        #expect(sut.items.count == 2)
    }
}
