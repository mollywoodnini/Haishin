//
//  LibraryView.swift
//  Miru
//
//  Created by Miru on 24.01.26.
//

import SwiftUI

/// The library view showing saved anime.
struct LibraryView: View {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    @State private var viewModel = LibraryViewModel()
    @State private var selectedCategory: LibraryCategory = .watching


    //#################################################################################
    // MARK: - Body
    //#################################################################################

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                categoryPicker

                if viewModel.filteredItems(for: selectedCategory).isEmpty {
                    emptyStateView
                } else {
                    libraryList
                }
            }
            .navigationTitle("Library")
        }
    }


    //#################################################################################
    // MARK: - Subviews
    //#################################################################################

    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: .spacingXS) {
                ForEach(LibraryCategory.allCases) { category in
                    CategoryChip(category: category,
                                 isSelected: selectedCategory == category,
                                 count: viewModel.filteredItems(for: category).count) {
                        selectedCategory = category
                    }
                }
            }
            .padding(.horizontal, .spacingS)
            .padding(.vertical, .spacingXS)
        }
    }

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Anime", systemImage: selectedCategory.iconName)
        } description: {
            Text("Anime you add to \(selectedCategory.displayName) will appear here.")
        }
    }

    private var libraryList: some View {
        List {
            ForEach(viewModel.filteredItems(for: selectedCategory)) { item in
                LibraryItemRow(item: item)
            }
            .onDelete { indexSet in
                viewModel.deleteItems(at: indexSet, in: selectedCategory)
            }
        }
        .listStyle(.plain)
    }
}


//#################################################################################
// MARK: - CategoryChip
//#################################################################################

/// A chip button for selecting a library category.
private struct CategoryChip: View {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    let category: LibraryCategory
    let isSelected: Bool
    let count: Int
    let action: () -> Void


    //#################################################################################
    // MARK: - Body
    //#################################################################################

    var body: some View {
        Button(action: action) {
            HStack(spacing: .spacingXXS) {
                Image(systemName: category.iconName)
                Text(category.displayName)
                if count > 0 {
                    Text("\(count)")
                        .font(.caption2)
                        .padding(.horizontal, .spacingXXS)
                        .background(Capsule().fill(.secondary.opacity(0.3)))
                }
            }
            .font(.subheadline)
            .padding(.horizontal, .spacingS)
            .padding(.vertical, .spacingXS)
            .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.15))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}


//#################################################################################
// MARK: - LibraryItemRow
//#################################################################################

/// A row displaying a library item.
private struct LibraryItemRow: View {

    //#################################################################################
    // MARK: - Constants
    //#################################################################################

    private struct Constants {
        static let thumbnailSize: CGFloat = 60
    }


    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    let item: LibraryItem


    //#################################################################################
    // MARK: - Body
    //#################################################################################

    var body: some View {
        HStack(spacing: .spacingS) {
            AsyncImage(url: item.anime.coverURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
            }
            .frame(width: Constants.thumbnailSize, height: Constants.thumbnailSize)
            .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusXS))

            VStack(alignment: .leading, spacing: .spacingXXS) {
                Text(item.anime.title)
                    .font(.body)
                    .lineLimit(2)

                if let episode = item.lastWatchedEpisode {
                    Text("Episode \(episode)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .contentShape(Rectangle())
    }
}


//#################################################################################
// MARK: - Preview
//#################################################################################

#Preview {
    LibraryView()
}
