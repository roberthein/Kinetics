import SwiftUI

/// A flexible layout that arranges subviews in a flowing manner, wrapping to new lines when needed.
/// Similar to CSS flexbox with wrap behavior, this layout automatically distributes subviews across
/// multiple rows based on available width and spacing constraints.
struct FlowLayout: Layout {

    // MARK: - Public Interface

    /// Defines how subviews are aligned within each row
    enum RowAlignment {
        case leading
        case center
        case trailing
    }

    /// The spacing between subviews horizontally and vertically
    let spacing: CGFloat
    /// How subviews are aligned within each row
    let rowAlignment: RowAlignment

    // MARK: - Initialization

    /// Creates a new FlowLayout with specified spacing and alignment
    /// - Parameters:
    ///   - spacing: The spacing between subviews (default: 8 points)
    ///   - rowAlignment: How to align subviews within each row (default: .leading)
    init(spacing: CGFloat = 8, rowAlignment: RowAlignment = .leading) {
        self.spacing = spacing
        self.rowAlignment = rowAlignment
    }

    // MARK: - Layout Protocol Implementation

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void
    ) -> CGSize {
        let availableWidth = proposal.width ?? 0
        let calculatedHeight = calculateTotalHeight(
            proposal: proposal,
            subviews: subviews,
            availableWidth: availableWidth
        )

        return CGSize(width: availableWidth, height: calculatedHeight)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void
    ) {
        let organizedRows = organizeSubviewsIntoRows(
            proposal: proposal,
            subviews: subviews,
            availableWidth: bounds.width
        )

        placeRowsInBounds(
            rows: organizedRows,
            bounds: bounds,
            proposal: proposal
        )
    }

    // MARK: - Private Helper Methods

    /// Calculates the total height needed for all rows including spacing
    private func calculateTotalHeight(
        proposal: ProposedViewSize,
        subviews: Subviews,
        availableWidth: CGFloat
    ) -> CGFloat {
        let rows = organizeSubviewsIntoRows(
            proposal: proposal,
            subviews: subviews,
            availableWidth: availableWidth
        )

        let totalRowHeights = rows.reduce(0) { accumulatedHeight, row in
            let maxRowHeight = row.map { $0.size.height }.max() ?? 0
            return accumulatedHeight + maxRowHeight
        }

        let totalSpacingHeight = calculateVerticalSpacing(for: rows.count)

        return totalRowHeights + totalSpacingHeight
    }

    /// Organizes subviews into rows based on available width and spacing
    private func organizeSubviewsIntoRows(
        proposal: ProposedViewSize,
        subviews: Subviews,
        availableWidth: CGFloat
    ) -> [[SubviewLayoutInfo]] {
        var organizedRows: [[SubviewLayoutInfo]] = []
        var currentRow: [SubviewLayoutInfo] = []
        var currentRowWidth: CGFloat = 0

        for subview in subviews {
            let subviewSize = subview.sizeThatFits(proposal)
            let subviewInfo = SubviewLayoutInfo(subview: subview, size: subviewSize)

            let wouldBeRowWidth = calculateRowWidthIfAddingSubview(
                currentRowWidth: currentRowWidth,
                subviewWidth: subviewSize.width,
                isFirstSubview: currentRow.isEmpty
            )

            if canFitSubviewInCurrentRow(
                wouldBeRowWidth: wouldBeRowWidth,
                availableWidth: availableWidth,
                isFirstSubview: currentRow.isEmpty
            ) {
                // Add to current row
                currentRow.append(subviewInfo)
                currentRowWidth = wouldBeRowWidth
            } else {
                // Start new row
                if !currentRow.isEmpty {
                    organizedRows.append(currentRow)
                }
                currentRow = [subviewInfo]
                currentRowWidth = subviewSize.width
            }
        }

        // Add the last row if it contains any subviews
        if !currentRow.isEmpty {
            organizedRows.append(currentRow)
        }

        return organizedRows
    }

    /// Places all rows within the given bounds according to alignment
    private func placeRowsInBounds(
        rows: [[SubviewLayoutInfo]],
        bounds: CGRect,
        proposal: ProposedViewSize
    ) {
        var currentYPosition = bounds.origin.y

        for row in rows {
            let rowWidth = calculateRowWidth(row: row)
            let rowStartX = calculateRowStartX(
                rowWidth: rowWidth,
                bounds: bounds
            )

            placeRow(
                row: row,
                startX: rowStartX,
                yPosition: currentYPosition,
                proposal: proposal
            )

            let maxRowHeight = row.map { $0.size.height }.max() ?? 0
            currentYPosition += maxRowHeight + spacing
        }
    }

    /// Places a single row of subviews at the specified position
    private func placeRow(
        row: [SubviewLayoutInfo],
        startX: CGFloat,
        yPosition: CGFloat,
        proposal: ProposedViewSize
    ) {
        var currentXPosition = startX

        for subviewInfo in row {
            let position = CGPoint(x: currentXPosition, y: yPosition)
            subviewInfo.subview.place(at: position, proposal: proposal)
            currentXPosition += subviewInfo.size.width + spacing
        }
    }

    // MARK: - Calculation Helpers

    /// Calculates the width a row would have if a subview were added
    private func calculateRowWidthIfAddingSubview(
        currentRowWidth: CGFloat,
        subviewWidth: CGFloat,
        isFirstSubview: Bool
    ) -> CGFloat {
        let spacingForNewSubview = isFirstSubview ? 0 : spacing
        return currentRowWidth + spacingForNewSubview + subviewWidth
    }

    /// Determines if a subview can fit in the current row
    private func canFitSubviewInCurrentRow(
        wouldBeRowWidth: CGFloat,
        availableWidth: CGFloat,
        isFirstSubview: Bool
    ) -> Bool {
        // Always allow the first subview, even if it exceeds available width
        return wouldBeRowWidth <= availableWidth || isFirstSubview
    }

    /// Calculates the total width of a row including spacing
    private func calculateRowWidth(row: [SubviewLayoutInfo]) -> CGFloat {
        let subviewsWidth = row.reduce(0) { $0 + $1.size.width }
        let spacingWidth = CGFloat(max(0, row.count - 1)) * spacing
        return subviewsWidth + spacingWidth
    }

    /// Calculates the starting X position for a row based on alignment
    private func calculateRowStartX(rowWidth: CGFloat, bounds: CGRect) -> CGFloat {
        switch rowAlignment {
        case .leading:
            return bounds.minX
        case .center:
            return bounds.minX + (bounds.width - rowWidth) / 2
        case .trailing:
            return bounds.maxX - rowWidth
        }
    }

    /// Calculates the total vertical spacing needed between rows
    private func calculateVerticalSpacing(for rowCount: Int) -> CGFloat {
        let spacingBetweenRows = CGFloat(max(0, rowCount - 1))
        return spacingBetweenRows * spacing
    }

    // MARK: - Supporting Types

    /// Encapsulates information about a subview for layout calculations
    private struct SubviewLayoutInfo {
        let subview: LayoutSubview
        let size: CGSize
    }
}

// MARK: - Preview

#Preview("FlowLayout") {
    ScrollView {
        VStack(spacing: 30) {
            // Example 1: Leading alignment with tags
            VStack(alignment: .leading, spacing: 8) {
                Text("Leading Alignment")
                    .font(.headline)

                FlowLayout(spacing: 8, rowAlignment: .leading) {
                    Text("SwiftUI")
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(16)

                    Text("UIKit")
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(16)

                    Text("Core Data")
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(16)

                    Text("Combine")
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(16)

                    Text("Swift")
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(16)

                    Text("Xcode")
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(16)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }

            // Example 2: Center alignment with buttons
            VStack(alignment: .leading, spacing: 8) {
                Text("Center Alignment")
                    .font(.headline)

                FlowLayout(spacing: 12, rowAlignment: .center) {
                    Button(action: {}) {
                        Text("Edit")
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }

                    Button(action: {}) {
                        Text("Delete")
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }

                    Button(action: {}) {
                        Text("Share")
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }

                    Button(action: {}) {
                        Text("Favorite")
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }

            // Example 3: Trailing alignment with icons
            VStack(alignment: .leading, spacing: 8) {
                Text("Trailing Alignment")
                    .font(.headline)

                FlowLayout(spacing: 16, rowAlignment: .trailing) {
                    Image(systemName: "star.fill")
                        .font(.title2)
                        .foregroundColor(.orange)
                        .frame(width: 40, height: 40)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(20)

                    Image(systemName: "heart.fill")
                        .font(.title2)
                        .foregroundColor(.orange)
                        .frame(width: 40, height: 40)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(20)

                    Image(systemName: "bookmark.fill")
                        .font(.title2)
                        .foregroundColor(.orange)
                        .frame(width: 40, height: 40)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(20)

                    Image(systemName: "flag.fill")
                        .font(.title2)
                        .foregroundColor(.orange)
                        .frame(width: 40, height: 40)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(20)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }

            // Example 4: Mixed content sizes
            VStack(alignment: .leading, spacing: 8) {
                Text("Mixed Content Sizes")
                    .font(.headline)

                FlowLayout(spacing: 10, rowAlignment: .leading) {
                    Text("Short")
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.purple.opacity(0.2))
                        .cornerRadius(4)

                    Text("Medium Text")
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.purple.opacity(0.2))
                        .cornerRadius(6)

                    Text("Longer Text Element")
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.purple.opacity(0.2))
                        .cornerRadius(8)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }

            // Example 5: Responsive behavior
            VStack(alignment: .leading, spacing: 8) {
                Text("Responsive Behavior")
                    .font(.headline)

                Text("Items wrap to new lines automatically")
                    .font(.caption)
                    .foregroundColor(.secondary)

                FlowLayout(spacing: 6, rowAlignment: .leading) {
                    Text("Item 1")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red.opacity(0.1))
                        .foregroundColor(.red)
                        .cornerRadius(4)

                    Text("Item 2")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red.opacity(0.1))
                        .foregroundColor(.red)
                        .cornerRadius(4)

                    Text("Item 3")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red.opacity(0.1))
                        .foregroundColor(.red)
                        .cornerRadius(4)

                    Text("Item 4")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red.opacity(0.1))
                        .foregroundColor(.red)
                        .cornerRadius(4)

                    Text("Item 5")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red.opacity(0.1))
                        .foregroundColor(.red)
                        .cornerRadius(4)

                    Text("Item 6")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red.opacity(0.1))
                        .foregroundColor(.red)
                        .cornerRadius(4)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding()
    }
    .navigationTitle("FlowLayout Examples")
}
