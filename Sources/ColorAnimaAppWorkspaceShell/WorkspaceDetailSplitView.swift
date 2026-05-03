import SwiftUI

private let workspaceSplitDividerThickness: CGFloat = 1
private let workspaceSplitDividerHitWidth: CGFloat = 12

package struct WorkspaceDetailSplitSizing {
    static func clampedInspectorWidth(
        desired: CGFloat,
        availableWidth: CGFloat,
        minimumLeadingWidth: CGFloat,
        range: ClosedRange<CGFloat>,
        dividerThickness: CGFloat
    ) -> CGFloat {
        let maxInspectorWidth = max(0, availableWidth - dividerThickness - minimumLeadingWidth)
        let effectiveUpperBound = min(range.upperBound, maxInspectorWidth)

        guard effectiveUpperBound >= range.lowerBound else {
            return maxInspectorWidth
        }

        return min(max(desired, range.lowerBound), effectiveUpperBound)
    }

    static func leadingWidth(
        availableWidth: CGFloat,
        inspectorWidth: CGFloat,
        dividerThickness: CGFloat
    ) -> CGFloat {
        max(0, availableWidth - dividerThickness - inspectorWidth)
    }

    static func constrainedLeadingPosition(
        proposedLeadingWidth: CGFloat,
        availableWidth: CGFloat,
        minimumLeadingWidth: CGFloat,
        inspectorWidthRange: ClosedRange<CGFloat>,
        dividerThickness: CGFloat
    ) -> CGFloat {
        let minimumPosition = max(
            minimumLeadingWidth,
            availableWidth - dividerThickness - inspectorWidthRange.upperBound
        )
        let maximumPosition = max(
            minimumPosition,
            availableWidth - dividerThickness - inspectorWidthRange.lowerBound
        )

        return min(max(proposedLeadingWidth, minimumPosition), maximumPosition)
    }
}

package struct WorkspaceDetailSplitView<Leading: View, Trailing: View>: View {
    @Binding private var inspectorWidth: CGFloat

    private let minimumLeadingWidth: CGFloat
    private let inspectorWidthRange: ClosedRange<CGFloat>
    private let dividerColor: Color
    private let leading: Leading
    private let trailing: Trailing

    @State private var dragStartLeadingWidth: CGFloat?

    package init(
        inspectorWidth: Binding<CGFloat>,
        minimumLeadingWidth: CGFloat,
        inspectorWidthRange: ClosedRange<CGFloat>,
        dividerColor: Color,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) {
        _inspectorWidth = inspectorWidth
        self.minimumLeadingWidth = minimumLeadingWidth
        self.inspectorWidthRange = inspectorWidthRange
        self.dividerColor = dividerColor
        self.leading = leading()
        self.trailing = trailing()
    }

    package var body: some View {
        GeometryReader { geometry in
            let availableWidth = geometry.size.width
            let displayedInspectorWidth = WorkspaceDetailSplitSizing.clampedInspectorWidth(
                desired: inspectorWidth,
                availableWidth: availableWidth,
                minimumLeadingWidth: minimumLeadingWidth,
                range: inspectorWidthRange,
                dividerThickness: workspaceSplitDividerThickness
            )
            let leadingWidth = WorkspaceDetailSplitSizing.leadingWidth(
                availableWidth: availableWidth,
                inspectorWidth: displayedInspectorWidth,
                dividerThickness: workspaceSplitDividerThickness
            )

            ZStack(alignment: .leading) {
                leading
                    .frame(width: leadingWidth, height: geometry.size.height, alignment: .topLeading)

                trailing
                    .frame(
                        width: displayedInspectorWidth,
                        height: geometry.size.height,
                        alignment: .topLeading
                    )
                    .offset(x: leadingWidth + workspaceSplitDividerThickness)

                Rectangle()
                    .fill(dividerColor)
                    .frame(width: workspaceSplitDividerThickness, height: geometry.size.height)
                    .offset(x: leadingWidth)

                Color.clear
                    .contentShape(Rectangle())
                    .frame(width: workspaceSplitDividerHitWidth, height: geometry.size.height)
                    .offset(
                        x: leadingWidth - ((workspaceSplitDividerHitWidth - workspaceSplitDividerThickness) / 2)
                    )
                    .gesture(dividerDragGesture(availableWidth: availableWidth, leadingWidth: leadingWidth))
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .leading)
            .clipped()
        }
    }

    private func dividerDragGesture(availableWidth: CGFloat, leadingWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if dragStartLeadingWidth == nil {
                    dragStartLeadingWidth = leadingWidth
                }

                let originLeadingWidth = dragStartLeadingWidth ?? leadingWidth
                let proposedLeadingWidth = originLeadingWidth + value.translation.width
                inspectorWidth = resolvedInspectorWidth(
                    availableWidth: availableWidth,
                    proposedLeadingWidth: proposedLeadingWidth
                )
            }
            .onEnded { value in
                let originLeadingWidth = dragStartLeadingWidth ?? leadingWidth
                let proposedLeadingWidth = originLeadingWidth + value.translation.width
                inspectorWidth = resolvedInspectorWidth(
                    availableWidth: availableWidth,
                    proposedLeadingWidth: proposedLeadingWidth
                )
                dragStartLeadingWidth = nil
            }
    }

    private func resolvedInspectorWidth(
        availableWidth: CGFloat,
        proposedLeadingWidth: CGFloat
    ) -> CGFloat {
        let constrainedLeadingWidth = WorkspaceDetailSplitSizing.constrainedLeadingPosition(
            proposedLeadingWidth: proposedLeadingWidth,
            availableWidth: availableWidth,
            minimumLeadingWidth: minimumLeadingWidth,
            inspectorWidthRange: inspectorWidthRange,
            dividerThickness: workspaceSplitDividerThickness
        )

        return max(0, availableWidth - workspaceSplitDividerThickness - constrainedLeadingWidth)
    }
}
