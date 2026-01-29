//
//  ProgressBarView.swift
//  Haishin
//
//  Created by Tan Nghia La on 25.01.26.
//

import SwiftUI


//#################################################################################
// MARK: - ProgressBarView
//#################################################################################

/// A simple progress bar view for displaying watch or download progress.
struct ProgressBarView: View {

    //#################################################################################
    // MARK: - Constants
    //#################################################################################

    private struct Constants {
        static let barHeight: CGFloat = 4
    }


    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    private let progress: Double


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new progress bar view.
    /// - Parameter progress: The progress value between 0 and 1.
    init(progress: Double) {
        self.progress = progress
    }


    //#################################################################################
    // MARK: - Body
    //#################################################################################

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: Constants.barHeight / 2)
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: Constants.barHeight)

                RoundedRectangle(cornerRadius: Constants.barHeight / 2)
                    .fill(Color.accentColor)
                    .frame(width: geometry.size.width * progress, height: Constants.barHeight)
            }
        }
        .frame(height: Constants.barHeight)
    }
}
