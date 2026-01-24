//
//  BrowseView.swift
//  Miru
//
//  Created by Miru on 24.01.26.
//

import SwiftUI


//#################################################################################
// MARK: - BrowseView
//#################################################################################

/// The main browse view showing anime recommendations from AniList.
struct BrowseView: View {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    @State private var viewModel: BrowseViewModel
    private let sourceManager: SourceManaging


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new browse view.
    /// - Parameter sourceManager: The source manager to use.
    init(sourceManager: SourceManaging) {
        self.sourceManager = sourceManager
        self._viewModel = State(initialValue: BrowseViewModel(sourceManager: sourceManager))
    }


    //#################################################################################
    // MARK: - Body
    //#################################################################################

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: .spacingM) {
                    ForEach(viewModel.sections) { section in
                        RecommendationSectionView(section: section)
                    }
                }
                .padding(.vertical, .spacingS)
            }
            .navigationTitle("Browse")
            .task {
                await viewModel.loadContent()
            }
            .refreshable {
                await viewModel.refresh()
            }
            .overlay {
                if viewModel.isLoading && viewModel.sections.allSatisfy({ $0.items.isEmpty }) {
                    ProgressView()
                }
            }
        }
    }
}


//#################################################################################
// MARK: - Preview
//#################################################################################

#Preview {
    BrowseView(sourceManager: SourceManager())
}
