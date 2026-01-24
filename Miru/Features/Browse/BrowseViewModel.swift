//
//  BrowseViewModel.swift
//  Miru
//
//  Created by Miru on 24.01.26.
//

import Foundation


//#################################################################################
// MARK: - BrowseViewModel
//#################################################################################

/// ViewModel for the browse screen showing anime recommendations.
@Observable
final class BrowseViewModel {

    //#################################################################################
    // MARK: - Section Identifiers
    //#################################################################################

    private enum SectionId {
        static let thisWeek = "this-week"
        static let trending = "trending"
        static let seasonal = "seasonal"
    }


    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    /// All recommendation sections to display.
    private(set) var sections: [RecommendationSection] = []

    /// Whether the initial load is in progress.
    private(set) var isLoading = false

    /// The last error that occurred.
    private(set) var error: Error?

    /// Installed sources from the source manager.
    var installedSources: [InstalledSource] {
        sourceManager.installedSources
    }

    private let sourceManager: SourceManaging
    private let aniListService: AniListServicing


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new browse view model.
    /// - Parameters:
    ///   - sourceManager: The source manager to use.
    ///   - aniListService: The AniList service for fetching recommendations.
    init(sourceManager: SourceManaging,
         aniListService: AniListServicing = AniListService()) {
        self.sourceManager = sourceManager
        self.aniListService = aniListService
        initializeSections()
    }


    //#################################################################################
    // MARK: - Public Methods
    //#################################################################################

    /// Loads content for all recommendation sections.
    func loadContent() async {
        guard !isLoading else { return }

        isLoading = true
        error = nil

        // Load all sections concurrently
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadThisWeek() }
            group.addTask { await self.loadTrending() }
            group.addTask { await self.loadSeasonal() }
        }

        isLoading = false
    }

    /// Refreshes all content.
    func refresh() async {
        resetSections()
        await loadContent()
    }


    //#################################################################################
    // MARK: - Private Methods
    //#################################################################################

    private func initializeSections() {
        let (season, year) = currentSeasonName()

        sections = [
            RecommendationSection(id: SectionId.thisWeek,
                                  title: "This Week",
                                  subtitle: nil,
                                  style: .thisWeek,
                                  listType: nil,
                                  loadingState: .idle),
            RecommendationSection(id: SectionId.trending,
                                  title: "Trending",
                                  subtitle: nil,
                                  style: .standard,
                                  listType: .trending,
                                  loadingState: .idle),
            RecommendationSection(id: SectionId.seasonal,
                                  title: "Seasonal Anime",
                                  subtitle: "\(season) \(year)",
                                  style: .standard,
                                  listType: .seasonal,
                                  loadingState: .idle)
        ]
    }

    private func resetSections() {
        for index in sections.indices {
            sections[index].items = []
            sections[index].loadingState = .idle
        }
    }

    private func loadThisWeek() async {
        await updateSectionState(id: SectionId.thisWeek, state: .loading)

        do {
            let items = try await aniListService.fetchThisWeek()
            await MainActor.run {
                if let index = sections.firstIndex(where: { $0.id == SectionId.thisWeek }) {
                    sections[index].items = items
                    sections[index].loadingState = .loaded
                }
            }
        } catch {
            await updateSectionState(id: SectionId.thisWeek,
                                     state: .failed(error.localizedDescription))
        }
    }

    private func loadTrending() async {
        await updateSectionState(id: SectionId.trending, state: .loading)

        do {
            let response = try await aniListService.fetchTrending(page: 1)
            await MainActor.run {
                if let index = sections.firstIndex(where: { $0.id == SectionId.trending }) {
                    sections[index].items = response.items
                    sections[index].loadingState = .loaded
                }
            }
        } catch {
            await updateSectionState(id: SectionId.trending,
                                     state: .failed(error.localizedDescription))
        }
    }

    private func loadSeasonal() async {
        await updateSectionState(id: SectionId.seasonal, state: .loading)

        do {
            let response = try await aniListService.fetchSeasonal(page: 1)
            await MainActor.run {
                if let index = sections.firstIndex(where: { $0.id == SectionId.seasonal }) {
                    sections[index].items = response.items
                    sections[index].loadingState = .loaded
                }
            }
        } catch {
            await updateSectionState(id: SectionId.seasonal,
                                     state: .failed(error.localizedDescription))
        }
    }

    @MainActor
    private func updateSectionState(id: String, state: LoadingState) {
        if let index = sections.firstIndex(where: { $0.id == id }) {
            sections[index].loadingState = state
        }
    }

    private func currentSeasonName() -> (season: String, year: Int) {
        let calendar = Calendar.current
        let now = Date()
        let month = calendar.component(.month, from: now)
        let year = calendar.component(.year, from: now)

        let season: String
        switch month {
        case 1...3:
            season = "Winter"
        case 4...6:
            season = "Spring"
        case 7...9:
            season = "Summer"
        default:
            season = "Fall"
        }

        return (season, year)
    }
}
