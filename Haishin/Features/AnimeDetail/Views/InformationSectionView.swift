//
//  InformationSectionView.swift
//  Miru
//
//  Created by Miru on 24.01.26.
//

import SwiftUI


//#################################################################################
// MARK: - InformationSectionView
//#################################################################################

/// A section view displaying key-value information items.
struct InformationSectionView: View {

    //#################################################################################
    // MARK: - Types
    //#################################################################################

    /// A key-value information item.
    struct Item: Identifiable {

        //#################################################################################
        // MARK: - Properties
        //#################################################################################

        let id = UUID()
        let key: String
        let value: String
    }


    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    private let items: [Item]


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new information section view.
    /// - Parameter items: The list of key-value items to display.
    init(items: [Item]) {
        self.items = items
    }


    //#################################################################################
    // MARK: - Body
    //#################################################################################

    var body: some View {
        VStack(alignment: .leading, spacing: .spacingXS) {
            SectionHeader(title: "Information")

            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    HStack {
                        Text(item.key)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Text(item.value)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                    }
                    .padding(.vertical, .spacingXS)
                    .padding(.horizontal, .spacingS)

                    if index < items.count - 1 {
                        Divider()
                            .padding(.leading, .spacingS)
                    }
                }
            }
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusS))
            .padding(.horizontal, .spacingS)
        }
        .padding(.top, .spacingS)
    }
}
