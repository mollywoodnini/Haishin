//
//  AnimeDetailErrorView.swift
//  Miru
//
//  Created by Miru on 24.01.26.
//

import SwiftUI

/// An error view for anime details with retry functionality.
struct AnimeDetailErrorView: View {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    private let error: Error
    private let onRetry: () async -> Void


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new error view.
    /// - Parameter error: The error to display.
    /// - Parameter onRetry: Async closure called when the retry button is tapped.
    init(error: Error, onRetry: @escaping () async -> Void) {
        self.error = error
        self.onRetry = onRetry
    }


    //#################################################################################
    // MARK: - Body
    //#################################################################################

    var body: some View {
        VStack(spacing: .spacingS) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.secondary)

            Text("Failed to load details")
                .font(.headline)

            Text(error.localizedDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Retry") {
                Task {
                    await onRetry()
                }
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .padding(.spacingM)
    }
}
