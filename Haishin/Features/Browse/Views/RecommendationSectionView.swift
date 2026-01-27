//
//  RecommendationSectionView.swift
//  Haishin
//
//  Created by Haishin on 24.01.26.
//

import SwiftUI


//#################################################################################
// MARK: - RecommendationSectionView
//#################################################################################

/// A view displaying a single recommendation section with header and content.
struct RecommendationSectionView: View {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    private let section: RecommendationSection


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new recommendation section view.
    /// - Parameter section: The recommendation section to display.
    init(section: RecommendationSection) {
        self.section = section
    }


    //#################################################################################
    // MARK: - Body
    //#################################################################################

    var body: some View {
        VStack(alignment: .leading, spacing: .spacingXS) {
            sectionHeader

            switch section.loadingState {
            case .loading where section.items.isEmpty:
                loadingView
            case .failed(let message):
                errorView(message: message)
            default:
                sectionContent
            }
        }
    }


    //#################################################################################
    // MARK: - Section Header
    //#################################################################################

    private var sectionHeader: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: .spacingXXS) {
                Text(section.title)
                    .font(.title2)
                    .fontWeight(.bold)

                if let subtitle = section.subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Action button based on section style
            switch section.style {
            case .thisWeek:
                NavigationLink(destination: ScheduleView()) {
                    Text("Show Schedule")
                        .font(.subheadline)
                        .foregroundStyle(.accent)
                }
            case .standard, .wide:
                if let listType = section.listType {
                    NavigationLink(destination: AnimeListView(title: section.title, listType: listType)) {
                        Text("View More")
                            .font(.subheadline)
                            .foregroundStyle(.accent)
                    }
                }
            }
        }
        .padding(.horizontal, .spacingS)
    }


    //#################################################################################
    // MARK: - Loading View
    //#################################################################################

    private var loadingView: some View {
        HStack {
            Spacer()
            ProgressView()
            Spacer()
        }
        .frame(height: 200)
    }


    //#################################################################################
    // MARK: - Error View
    //#################################################################################

    private func errorView(message: String) -> some View {
        HStack {
            Spacer()
            VStack(spacing: .spacingXS) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.title)
                    .foregroundStyle(.secondary)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Spacer()
        }
        .padding(.spacingS)
    }


    //#################################################################################
    // MARK: - Section Content
    //#################################################################################

    @ViewBuilder
    private var sectionContent: some View {
        if section.items.isEmpty {
            EmptyView()
        } else {
            switch section.style {
            case .thisWeek:
                ThisWeekSectionContent(items: section.items)
            case .standard, .wide:
                StandardSectionContent(items: section.items)
            }
        }
    }
}
