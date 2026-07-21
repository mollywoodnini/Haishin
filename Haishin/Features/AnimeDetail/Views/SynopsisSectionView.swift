//
//  SynopsisSectionView.swift
//  Haishin
//
//  Created by Haishin on 24.01.26.
//

import SwiftUI


//#################################################################################
// MARK: - SynopsisSectionView
//#################################################################################

/// A section view displaying an expandable synopsis.
struct SynopsisSectionView: View {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    private let synopsis: String
    @Binding private var isExpanded: Bool
    @State private var isTruncated = false


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new synopsis section view.
    /// - Parameters:
    ///   - synopsis: The synopsis text to display.
    ///   - isExpanded: Binding to control the expanded state.
    init(synopsis: String, isExpanded: Binding<Bool>) {
        self.synopsis = synopsis
        self._isExpanded = isExpanded
    }


    //#################################################################################
    // MARK: - Body
    //#################################################################################

    var body: some View {
        VStack(alignment: .leading, spacing: .spacingXS) {
            SectionHeader(title: "Synopsis")

            VStack(alignment: .leading, spacing: .spacingXS) {
                Text(synopsis)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(isExpanded ? nil : 4)
                    .background {
                        GeometryReader { visibleGeometry in
                            Color.clear
                                .overlay {
                                    Text(synopsis)
                                        .font(.body)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .background {
                                            GeometryReader { fullGeometry in
                                                Color.clear.onAppear {
                                                    isTruncated = fullGeometry.size.height > visibleGeometry.size.height
                                                }
                                                .onChange(of: isExpanded) { _, _ in
                                                    isTruncated = fullGeometry.size.height > visibleGeometry.size.height
                                                }
                                            }
                                        }
                                        .hidden()
                                }
                        }
                    }

                if isTruncated || isExpanded {
                    Button(isExpanded ? "Show Less" : "Read More") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isExpanded.toggle()
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.accent)
                }
            }
            .padding(.horizontal, .spacingS)
        }
        .padding(.top, .spacingS)
    }
}
