//
//  LibraryWideCard.swift
//  Miru
//
//  Created by Miru on 24.01.26.
//

import SwiftUI


//#################################################################################
// MARK: - LibraryWideCard
//#################################################################################

/// A wide card for library categories (spanning full width).
struct LibraryWideCard: View {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    private let icon: String
    private let title: String
    private let count: Int
    private let color: Color


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new library wide card.
    /// - Parameters:
    ///   - icon: The SF Symbol name for the card icon.
    ///   - title: The title text to display.
    ///   - count: The count to display.
    ///   - color: The color for the icon.
    init(icon: String, title: String, count: Int, color: Color) {
        self.icon = icon
        self.title = title
        self.count = count
        self.color = color
    }


    //#################################################################################
    // MARK: - Body
    //#################################################################################

    var body: some View {
        HStack(spacing: .spacingS) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)

            Spacer()

            Text("\(count)")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.spacingS)
        .frame(maxWidth: .infinity, minHeight: 56)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusM))
    }
}
