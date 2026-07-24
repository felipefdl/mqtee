//
//  FilterComponents.swift
//  mqtee
//

import SwiftUI

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var horizontalAlignment: HorizontalAlignment = .leading

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }

        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        // First pass: group subviews into rows
        var rows: [(subviews: [(LayoutSubviews.Element, CGSize)], width: CGFloat, height: CGFloat)] = []
        var currentRow: [(LayoutSubviews.Element, CGSize)] = []
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let neededWidth = currentRow.isEmpty ? size.width : rowWidth + spacing + size.width
            if neededWidth > bounds.width && !currentRow.isEmpty {
                rows.append((subviews: currentRow, width: rowWidth, height: rowHeight))
                currentRow = []
                rowWidth = 0
                rowHeight = 0
            }
            if !currentRow.isEmpty {
                rowWidth += spacing
            }
            rowWidth += size.width
            rowHeight = max(rowHeight, size.height)
            currentRow.append((subview, size))
        }
        if !currentRow.isEmpty {
            rows.append((subviews: currentRow, width: rowWidth, height: rowHeight))
        }

        // Second pass: place subviews with alignment offset
        var y = bounds.minY
        for row in rows {
            let xOffset: CGFloat = switch horizontalAlignment {
            case .center: (bounds.width - row.width) / 2
            case .trailing: bounds.width - row.width
            default: 0
            }
            var x = bounds.minX + xOffset
            for (subview, size) in row.subviews {
                subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }
}

struct FilterChip: View {
    var label: String
    var icon: String
    var color: Color
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                Text(label)
                    .font(.caption)
            }
            .fixedSize()
        }
        .buttonStyle(.glass)
        .tint(isSelected ? color : nil)
        .controlSize(.small)
        .animation(BrandTheme.springSnappy, value: isSelected)
    }
}
