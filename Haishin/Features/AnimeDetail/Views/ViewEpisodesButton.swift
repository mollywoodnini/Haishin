//
//  ViewEpisodesButton.swift
//  Miru
//
//  Created by Miru on 24.01.26.
//

import SwiftUI

/// A button that validates source selection before navigating to episodes.
struct ViewEpisodesButton: View {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    private let animeTitle: String
    private let selectedSourceId: Binding<String?>
    private let installedSources: [InstalledSource]
    private let validateSourceSelection: () -> Bool
    private let onNavigateToEpisodes: () -> Void

    @State private var showingSourcePicker = false


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new view episodes button.
    /// - Parameter animeTitle: The title of the anime to display in the source picker.
    /// - Parameter selectedSourceId: Binding to the currently selected source ID.
    /// - Parameter installedSources: The list of installed sources to choose from.
    /// - Parameter validateSourceSelection: Closure that validates if a source is selected.
    /// - Parameter onNavigateToEpisodes: Closure called when navigation should occur.
    init(animeTitle: String,
         selectedSourceId: Binding<String?>,
         installedSources: [InstalledSource],
         validateSourceSelection: @escaping () -> Bool,
         onNavigateToEpisodes: @escaping () -> Void) {
        self.animeTitle = animeTitle
        self.selectedSourceId = selectedSourceId
        self.installedSources = installedSources
        self.validateSourceSelection = validateSourceSelection
        self.onNavigateToEpisodes = onNavigateToEpisodes
    }


    //#################################################################################
    // MARK: - Body
    //#################################################################################

    var body: some View {
        Button {
            if validateSourceSelection() {
                onNavigateToEpisodes()
            } else {
                showingSourcePicker = true
            }
        } label: {
            Text("VIEW EPISODES")
                .font(.system(size: 15, weight: .bold))
        }
        .buttonStyle(.borderedProminent)
        .sheet(isPresented: $showingSourcePicker) {
            SourcePickerView(animeTitle: animeTitle,
                             selectedSourceId: selectedSourceId,
                             onSourceSelected: {
                                 showingSourcePicker = false
                                 DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                     onNavigateToEpisodes()
                                 }
                             },
                             sources: installedSources)
        }
    }
}
