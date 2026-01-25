//
//  InstalledSourceRow.swift
//  Miru
//
//  Created by Miru on 24.01.26.
//

import Kingfisher
import SwiftUI

/// A row displaying an installed source.
struct InstalledSourceRow: View {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    private let source: InstalledSource
    private let onSelect: () -> Void
    private let onDelete: () -> Void


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new installed source row.
    /// - Parameter source: The installed source to display.
    /// - Parameter onSelect: Closure called when the row is tapped to select this source.
    /// - Parameter onDelete: Closure called when the delete action is triggered.
    init(source: InstalledSource, onSelect: @escaping () -> Void, onDelete: @escaping () -> Void) {
        self.source = source
        self.onSelect = onSelect
        self.onDelete = onDelete
    }


    //#################################################################################
    // MARK: - Body
    //#################################################################################

    var body: some View {
        Button {
            onSelect()
        } label: {
            HStack(spacing: .spacingS) {
                iconView
                infoView
                Spacer()
                checkmarkView
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }


    //#################################################################################
    // MARK: - Subviews
    //#################################################################################

    private var iconView: some View {
        KFImage(source.info.iconURL)
            .resizable()
            .placeholder {
                Image(systemName: "globe")
                    .foregroundStyle(.secondary)
            }
            .aspectRatio(contentMode: .fit)
            .frame(width: 40, height: 40)
            .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusXS))
    }

    private var infoView: some View {
        VStack(alignment: .leading, spacing: .spacingXXS) {
            Text(source.info.name)
                .font(.body)

            HStack(spacing: .spacingXXS) {
                Text("v\(source.info.version)")
                Text("•")
                Text(source.info.language.uppercased())
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var checkmarkView: some View {
        if source.isEnabled {
            Image(systemName: "checkmark")
                .foregroundStyle(.tint)
                .fontWeight(.semibold)
        }
    }
}
