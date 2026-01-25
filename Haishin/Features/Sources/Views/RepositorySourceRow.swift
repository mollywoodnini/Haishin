//
//  RepositorySourceRow.swift
//  Miru
//
//  Created by Miru on 24.01.26.
//

import Kingfisher
import SwiftUI

/// A row displaying a source from a repository.
struct RepositorySourceRow: View {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    private let source: SourceInfo
    private let isInstalled: Bool
    private let onInstall: () -> Void


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new repository source row.
    /// - Parameter source: The source info to display.
    /// - Parameter isInstalled: Whether the source is already installed.
    /// - Parameter onInstall: Closure called when the install button is tapped.
    init(source: SourceInfo, isInstalled: Bool, onInstall: @escaping () -> Void) {
        self.source = source
        self.isInstalled = isInstalled
        self.onInstall = onInstall
    }


    //#################################################################################
    // MARK: - Body
    //#################################################################################

    var body: some View {
        HStack(spacing: .spacingS) {
            iconView
            infoView
            Spacer()
            actionView
        }
    }


    //#################################################################################
    // MARK: - Subviews
    //#################################################################################

    private var iconView: some View {
        KFImage(source.iconURL)
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
            HStack {
                Text(source.name)
                    .font(.body)

                if source.isNSFW {
                    Text("18+")
                        .font(.caption2)
                        .padding(.horizontal, .spacingXXS)
                        .background(Capsule().fill(.red))
                        .foregroundStyle(.white)
                }
            }

            HStack(spacing: .spacingXXS) {
                Text("v\(source.version)")
                Text("•")
                Text(source.language.uppercased())
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var actionView: some View {
        if isInstalled {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        } else {
            Button {
                onInstall()
            } label: {
                Image(systemName: "arrow.down.circle")
            }
            .buttonStyle(.plain)
        }
    }
}
