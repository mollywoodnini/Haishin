//
//  InstalledSourceRow.swift
//  Haishin
//
//  Created by Tan Nghia La on 24.01.26.
//

import Kingfisher
import SwiftUI

/// A row displaying an installed source.
struct InstalledSourceRow: View {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    private let source: InstalledSource
    private let hasUpdate: Bool
    private let onDelete: () -> Void


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new installed source row.
    /// - Parameters:
    ///   - source: The installed source to display.
    ///   - hasUpdate: Whether an update is available for this source.
    ///   - onDelete: Closure called when the delete action is triggered.
    init(source: InstalledSource, hasUpdate: Bool = false, onDelete: @escaping () -> Void) {
        self.source = source
        self.hasUpdate = hasUpdate
        self.onDelete = onDelete
    }


    //#################################################################################
    // MARK: - Body
    //#################################################################################

    var body: some View {
        HStack(spacing: .spacingS) {
            iconView
            infoView
            Spacer()
            if hasUpdate {
                updateBadge
            }
        }
        .contentShape(Rectangle())
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

    private var updateBadge: some View {
        Image(systemName: "arrow.up.circle.fill")
            .foregroundStyle(.blue)
            .imageScale(.medium)
    }
}
