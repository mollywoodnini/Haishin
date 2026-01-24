//
//  LibraryViewModel.swift
//  Miru
//
//  Created by Miru on 24.01.26.
//

import Foundation

/// ViewModel for the library screen.
@Observable
final class LibraryViewModel {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    /// All library items.
    private(set) var items: [LibraryItem] = []


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new library view model.
    init() {
        loadItems()
    }


    //#################################################################################
    // MARK: - Public Methods
    //#################################################################################

    /// Filters items by category.
    /// - Parameter category: The category to filter by.
    /// - Returns: Items matching the category.
    func filteredItems(for category: LibraryCategory) -> [LibraryItem] {
        items.filter { $0.category == category }
    }

    /// Adds an anime to the library.
    /// - Parameters:
    ///   - anime: The anime to add.
    ///   - category: The category to add it to.
    func addToLibrary(anime: AnimePreview, category: LibraryCategory = .planToWatch) {
        guard !items.contains(where: { $0.anime.id == anime.id && $0.anime.sourceId == anime.sourceId }) else {
            return
        }

        let item = LibraryItem(anime: anime, category: category)
        items.append(item)
        saveItems()
    }

    /// Updates the category of a library item.
    /// - Parameters:
    ///   - item: The item to update.
    ///   - category: The new category.
    func updateCategory(item: LibraryItem, to category: LibraryCategory) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].category = category
        saveItems()
    }

    /// Updates the watch progress of an item.
    /// - Parameters:
    ///   - item: The item to update.
    ///   - episode: The episode number.
    ///   - progress: The progress within the episode (0.0 to 1.0).
    func updateProgress(item: LibraryItem, episode: String, progress: Double) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].lastWatchedEpisode = episode
        items[index].lastWatchedProgress = progress
        items[index].lastWatchedAt = Date()

        // Auto-move to watching if currently in plan to watch
        if items[index].category == .planToWatch {
            items[index].category = .watching
        }

        saveItems()
    }

    /// Deletes items at the given indices.
    /// - Parameters:
    ///   - indexSet: The indices to delete.
    ///   - category: The category the items belong to.
    func deleteItems(at indexSet: IndexSet, in category: LibraryCategory) {
        let filtered = filteredItems(for: category)
        let idsToDelete = indexSet.map { filtered[$0].id }
        items.removeAll { idsToDelete.contains($0.id) }
        saveItems()
    }

    /// Removes an anime from the library.
    /// - Parameter item: The item to remove.
    func removeFromLibrary(item: LibraryItem) {
        items.removeAll { $0.id == item.id }
        saveItems()
    }


    //#################################################################################
    // MARK: - Private Methods
    //#################################################################################

    private func loadItems() {
        guard let data = UserDefaults.standard.data(forKey: "libraryItems"),
              let decoded = try? JSONDecoder().decode([LibraryItem].self, from: data) else {
            return
        }
        items = decoded
    }

    private func saveItems() {
        guard let encoded = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(encoded, forKey: "libraryItems")
    }
}
