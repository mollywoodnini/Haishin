//
//  AnimeDetailViewModel.swift
//  Miru
//
//  Created by Miru on 24.01.26.
//

import Foundation

/// ViewModel for the anime detail screen.
@Observable
final class AnimeDetailViewModel {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    /// The anime preview that was passed in.
    let preview: AnimePreview

    /// Full anime details, loaded asynchronously.
    private(set) var anime: Anime?

    /// Whether details are being loaded.
    private(set) var isLoading = false

    /// The last error that occurred.
    private(set) var error: Error?

    /// The currently selected episode for playback.
    private(set) var selectedEpisode: Episode?

    private let sourceManager: SourceManaging


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new anime detail view model.
    /// - Parameters:
    ///   - preview: The anime preview to load details for.
    ///   - sourceManager: The source manager to use.
    init(preview: AnimePreview, sourceManager: SourceManaging) {
        self.preview = preview
        self.sourceManager = sourceManager
    }


    //#################################################################################
    // MARK: - Public Methods
    //#################################################################################

    /// Loads the full anime details.
    func loadDetails() async {
        guard anime == nil, !isLoading else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            anime = try await sourceManager.getAnimeDetails(sourceId: preview.sourceId,
                                                            url: preview.detailsURL)
        } catch {
            self.error = error
            print("[AnimeDetailViewModel] Failed to load details: \(error)")
        }
    }

    /// Starts playback of an episode.
    /// - Parameter episode: The episode to play.
    func playEpisode(_ episode: Episode) {
        selectedEpisode = episode
        // TODO: Navigate to player view
        print("[AnimeDetailViewModel] Play episode: \(episode.number)")
    }
}
