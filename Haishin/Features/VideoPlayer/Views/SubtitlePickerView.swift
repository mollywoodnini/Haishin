//
//  SubtitlePickerView.swift
//  Haishin
//
//  Created by OpenCode on 26.01.26.
//

import SwiftUI


//#################################################################################
// MARK: - SubtitlePickerView
//#################################################################################

/// A menu for selecting subtitle tracks.
struct SubtitlePickerView: View {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    private let subtitles: [Subtitle]
    private let selectedSubtitle: Subtitle?
    private let onSelect: (Subtitle?) -> Void


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new subtitle picker view.
    /// - Parameters:
    ///   - subtitles: Available subtitle tracks.
    ///   - selectedSubtitle: Currently selected subtitle (nil if off).
    ///   - onSelect: Callback when a subtitle is selected.
    init(subtitles: [Subtitle],
         selectedSubtitle: Subtitle?,
         onSelect: @escaping (Subtitle?) -> Void) {
        self.subtitles = subtitles
        self.selectedSubtitle = selectedSubtitle
        self.onSelect = onSelect
    }


    //#################################################################################
    // MARK: - Body
    //#################################################################################

    var body: some View {
        Menu {
            // Off option
            Button {
                onSelect(nil)
            } label: {
                HStack {
                    Text("Off")
                    if selectedSubtitle == nil {
                        Image(systemName: "checkmark")
                    }
                }
            }

            Divider()

            // Available subtitles
            ForEach(subtitles) { subtitle in
                Button {
                    onSelect(subtitle)
                } label: {
                    HStack {
                        Text(subtitle.label)
                        if selectedSubtitle?.id == subtitle.id {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "captions.bubble")
                .font(.title2)
                .foregroundStyle(.white)
                .padding(.spacingS)
                .background(Circle().fill(Color.black.opacity(0.5)))
        }
    }
}


//#################################################################################
// MARK: - Preview
//#################################################################################

#Preview {
    ZStack {
        Color.black
        SubtitlePickerView(
            subtitles: [
                Subtitle(
                    id: "1",
                    language: "en",
                    label: "English",
                    url: URL(string: "https://example.com")!
                ),
                Subtitle(
                    id: "2",
                    language: "ja",
                    label: "Japanese",
                    url: URL(string: "https://example.com")!
                )
            ],
            selectedSubtitle: nil,
            onSelect: { _ in }
        )
    }
    .ignoresSafeArea()
}
