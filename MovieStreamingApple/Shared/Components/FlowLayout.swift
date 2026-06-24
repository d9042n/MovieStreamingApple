//
//  FlowLayout.swift
//  MovieStreamingApple
//
//  Shared flow layout for wrapping badges, tags, chips, and other inline elements.
//  Extracted from DetailHeaderView for reuse across ContentDetail, People, and other modules.
//

import SwiftUI

/// Reusable flow/wrapping layout — items flow left-to-right and wrap to new lines.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: ProposedViewSize(result.sizes[index])
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> ArrangeResult {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var sizes: [CGSize] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            sizes.append(size)
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x - spacing)   // right edge of the last placed item
        }

        let totalHeight = y + rowHeight
        // Report actual content width when the proposal is unconstrained (.infinity);
        // returning an infinite width breaks layout inside an HStack/ScrollView.
        let reportedWidth = maxWidth.isFinite ? maxWidth : maxX
        return ArrangeResult(
            size: CGSize(width: reportedWidth, height: totalHeight),
            positions: positions,
            sizes: sizes
        )
    }

    private struct ArrangeResult {
        let size: CGSize
        let positions: [CGPoint]
        let sizes: [CGSize]
    }
}
