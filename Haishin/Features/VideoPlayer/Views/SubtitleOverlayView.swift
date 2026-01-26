//
//  SubtitleOverlayView.swift
//  Haishin
//
//  Created by OpenCode on 26.01.26.
//

import SwiftUI


//#################################################################################
// MARK: - SubtitleOverlayView
//#################################################################################

/// Displays subtitle text over the video player.
struct SubtitleOverlayView: View {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    private let text: String


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new subtitle overlay view.
    /// - Parameter text: The subtitle text to display.
    init(text: String) {
        self.text = text
    }


    //#################################################################################
    // MARK: - Body
    //#################################################################################

    var body: some View {
        if !text.isEmpty {
            VStack {
                Spacer()
                Text(text)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, .spacingL)
                    .padding(.vertical, .spacingS)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.black.opacity(0.75))
                    )
                    .padding(.horizontal, .spacingM)
                    .padding(.bottom, 80) // Leave space for player controls
            }
        }
    }
}


//#################################################################################
// MARK: - Preview
//#################################################################################

#Preview {
    ZStack {
        Color.black
        SubtitleOverlayView(text: "This is a sample subtitle line.")
    }
    .ignoresSafeArea()
}
