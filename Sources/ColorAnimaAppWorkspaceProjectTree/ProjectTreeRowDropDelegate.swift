import ColorAnimaAppWorkspaceApplication
import SwiftUI
import UniformTypeIdentifiers

package func projectTreeRowDropTarget(delegate: some DropDelegate) -> some View {
    Color.clear.onDrop(of: [UTType.text], delegate: delegate)
}

package enum ProjectTreeRowDropPolicy {
    package static func resolvedDropPosition(
        location: CGPoint,
        rowHeight: CGFloat,
        draggedNodeIDs: Set<UUID>,
        nodeID: UUID,
        rootNode: WorkspaceProjectTreeNode
    ) -> ProjectTreeDropPosition? {
        let height = max(1, rowHeight)
        let relativeY = max(0, min(location.y / height, 1))

        let proposedPosition: ProjectTreeDropPosition
        if relativeY < 0.3 {
            proposedPosition = .before
        } else if relativeY > 0.7 {
            proposedPosition = .after
        } else {
            proposedPosition = .append
        }

        guard ProjectTreeActionRules.canMoveSelection(
            draggedNodeIDs,
            to: nodeID,
            position: proposedPosition,
            in: rootNode
        ) else {
            if proposedPosition == .append {
                let fallbackPosition: ProjectTreeDropPosition = relativeY < 0.5 ? .before : .after
                guard ProjectTreeActionRules.canMoveSelection(
                    draggedNodeIDs,
                    to: nodeID,
                    position: fallbackPosition,
                    in: rootNode
                ) else {
                    return nil
                }
                return fallbackPosition
            }
            return nil
        }

        return proposedPosition
    }
}

package struct ProjectTreeRowDropDelegate: DropDelegate {
    let node: WorkspaceProjectTreeNode
    let rootNode: WorkspaceProjectTreeNode
    let rowHeight: CGFloat
    let draggedNodeIDs: () -> [UUID]
    /// Returns the drop position that was last written for this row.
    /// Used in `dropUpdated` to skip redundant binding writes when the resolved
    /// position has not changed between consecutive drag-move events.
    let currentDropPosition: () -> ProjectTreeDropPosition?
    let setDropPosition: (ProjectTreeDropPosition?) -> Void
    let performMove: ([UUID], ProjectTreeDropPosition) -> Void
    let clearDragState: () -> Void

    package func validateDrop(info: DropInfo) -> Bool {
        resolvedDropPosition(for: info) != nil
    }

    package func dropEntered(info: DropInfo) {
        setDropPosition(resolvedDropPosition(for: info))
    }

    package func dropUpdated(info: DropInfo) -> DropProposal? {
        let position = resolvedDropPosition(for: info)
        // Only write when the resolved position differs from the current value.
        // This avoids repeated binding writes that would fan out SwiftUI
        // invalidation to all sibling rows on every drag-move event.
        if position != currentDropPosition() {
            setDropPosition(position)
        }
        guard position != nil else {
            return DropProposal(operation: .forbidden)
        }
        return DropProposal(operation: .move)
    }

    package func dropExited(info _: DropInfo) {
        setDropPosition(nil)
    }

    package func performDrop(info: DropInfo) -> Bool {
        defer {
            setDropPosition(nil)
            clearDragState()
        }

        guard let position = resolvedDropPosition(for: info) else { return false }
        performMove(draggedNodeIDs(), position)
        return true
    }

    private func resolvedDropPosition(for info: DropInfo) -> ProjectTreeDropPosition? {
        ProjectTreeRowDropPolicy.resolvedDropPosition(
            location: info.location,
            rowHeight: rowHeight,
            draggedNodeIDs: Set(draggedNodeIDs()),
            nodeID: node.id,
            rootNode: rootNode
        )
    }
}
