//
//  AnimeDetailLoadingView.swift
//  Haishin
//
//  Created by Haishin on 24.01.26.
//

import SwiftUI

/// A loading indicator view for anime details.
struct AnimeDetailLoadingView: View {

    //#################################################################################
    // MARK: - Body
    //#################################################################################

    var body: some View {
        VStack(spacing: .spacingM) {
            ProgressView()
            Text("Loading details...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, .spacingL)
    }
}
