//
//  BrowseViewModel.swift
//  Miru
//
//  Created by Miru on 24.01.26.
//

import Foundation

/// ViewModel for the browse screen.
@Observable
final class BrowseViewModel {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    /// Popular anime from installed sources.
    private(set) var popularAnime: [AnimePreview] = []

    /// Latest updated anime from installed sources.
    private(set) var latestAnime: [AnimePreview] = []

    /// Whether content is currently loading.
    private(set) var isLoading = false

    /// The last error that occurred.
    private(set) var error: Error?

    /// Installed sources from the source manager.
    var installedSources: [InstalledSource] {
        sourceManager.installedSources
    }

    private let sourceManager: SourceManaging


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new browse view model.
    /// - Parameter sourceManager: The source manager to use.
    init(sourceManager: SourceManaging) {
        self.sourceManager = sourceManager
    }


    //#################################################################################
    // MARK: - Public Methods
    //#################################################################################

    /// Loads content from all enabled sources.
    func loadContent() async {
        guard !isLoading else { return }

        isLoading = true
        defer { isLoading = false }

        let enabledSources = sourceManager.installedSources.filter { $0.isEnabled }

        await withTaskGroup(of: Void.self) { group in
            for source in enabledSources {
                group.addTask {
                    await self.loadPopular(from: source.id)
                }
                group.addTask {
                    await self.loadLatest(from: source.id)
                }
            }
        }
    }

    /// Refreshes all content.
    func refresh() async {
        popularAnime = []
        latestAnime = []
        await loadContent()
    }


    //#################################################################################
    // MARK: - Private Methods
    //#################################################################################

    private func loadPopular(from sourceId: String) async {
        do {
            let anime = try await sourceManager.getPopular(sourceId: sourceId, page: 1)
            await MainActor.run {
                popularAnime.append(contentsOf: anime)
            }
        } catch {
            print("[BrowseViewModel] Failed to load popular from \(sourceId): \(error)")
        }
    }

    private func loadLatest(from sourceId: String) async {
        do {
            let anime = try await sourceManager.getLatest(sourceId: sourceId, page: 1)
            await MainActor.run {
                latestAnime.append(contentsOf: anime)
            }
        } catch {
            print("[BrowseViewModel] Failed to load latest from \(sourceId): \(error)")
        }
    }
}
