//
//  FlowLayout.swift
//  Haishin
//
//  Created by Haishin on 24.01.26.
//

import SwiftUI


//#################################################################################
// MARK: - FlowLayout
//#################################################################################

/// A layout that arranges views in a flowing horizontal layout, wrapping to the next line as needed.
struct FlowLayout: Layout {

    //#################################################################################
    // MARK: - Properties
    //#################################################################################

    private let spacing: CGFloat


    //#################################################################################
    // MARK: - Initialization
    //#################################################################################

    /// Creates a new flow layout.
    /// - Parameter spacing: The spacing between items. Defaults to 8.
    init(spacing: CGFloat = 8) {
        self.spacing = spacing
    }


    //#################################################################################
    // MARK: - Layout Protocol
    //#################################################################################

    func sizeThatFits(proposal: ProposedViewSize,
                      subviews: Subviews,
                      cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect,
                       proposal: ProposedViewSize,
                       subviews: Subviews,
                       cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)

        for (index, subview) in subviews.enumerated() {
            subview.place(
                at: CGPoint(
                    x: bounds.minX + result.positions[index].x,
                    y: bounds.minY + result.positions[index].y
                ),
                proposal: .unspecified
            )
        }
    }


    //#################################################################################
    // MARK: - FlowResult
    //#################################################################################

    /// Helper struct for calculating flow layout positions.
    private struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > maxWidth, x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }

                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing
                self.size.width = max(self.size.width, x)
            }

            self.size.height = y + rowHeight
        }
    }
}
