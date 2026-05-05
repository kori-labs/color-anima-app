import ColorAnimaAppWorkspaceApplication
import ColorAnimaAppWorkspaceDesignSystem
import SwiftUI
import UniformTypeIdentifiers

package struct FrameStripInsertionSlot: View {
    let target: WorkspaceFrameDropTarget
    let allFrameIDs: [UUID]
    let draggedFrameIDs: () -> [UUID]
    let onMoveFrames: (WorkspaceFrameDropTarget) -> Void
    let width: CGFloat

    @State private var isTargeted = false

    package init(
        target: WorkspaceFrameDropTarget,
        allFrameIDs: [UUID],
        draggedFrameIDs: @escaping () -> [UUID],
        onMoveFrames: @escaping (WorkspaceFrameDropTarget) -> Void,
        width: CGFloat
    ) {
        self.target = target
        self.allFrameIDs = allFrameIDs
        self.draggedFrameIDs = draggedFrameIDs
        self.onMoveFrames = onMoveFrames
        self.width = width
    }

    package var body: some View {
        Color.clear
            .frame(width: width, height: 74)
            .overlay {
                if isTargeted {
                    RoundedRectangle(cornerRadius: WorkspaceFoundation.Metrics.microRadius, style: .continuous)
                        .fill(WorkspaceChromeStyle.selectionStroke)
                        .frame(width: 3, height: 58)
                        .shadow(color: WorkspaceChromeStyle.selectionStroke.opacity(WorkspaceFoundation.Metrics.badgeTintOpacity), radius: 2, y: 0)
                }
            }
            .contentShape(.rect)
            .onDrop(
                of: [UTType.text.identifier],
                delegate: FrameStripInsertionDropDelegate(
                    target: target,
                    allFrameIDs: allFrameIDs,
                    draggedFrameIDs: draggedFrameIDs,
                    setIsTargeted: { isTargeted = $0 },
                    performMove: onMoveFrames
                )
            )
    }
}
