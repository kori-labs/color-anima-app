import ColorAnimaAppWorkspaceApplication
import SwiftUI

package struct FrameStripInsertionDropDelegate: DropDelegate {
    let target: WorkspaceFrameDropTarget
    let allFrameIDs: [UUID]
    let draggedFrameIDs: () -> [UUID]
    let setIsTargeted: (Bool) -> Void
    let performMove: (WorkspaceFrameDropTarget) -> Void

    package func validateDrop(info: DropInfo) -> Bool {
        resolvedTarget(for: info) != nil
    }

    package func dropEntered(info: DropInfo) {
        setIsTargeted(resolvedTarget(for: info) != nil)
    }

    package func dropUpdated(info: DropInfo) -> DropProposal? {
        let resolvedTarget = resolvedTarget(for: info)
        setIsTargeted(resolvedTarget != nil)
        guard resolvedTarget != nil else { return DropProposal(operation: .forbidden) }
        return DropProposal(operation: .move)
    }

    package func dropExited(info: DropInfo) {
        setIsTargeted(false)
    }

    package func performDrop(info: DropInfo) -> Bool {
        defer {
            setIsTargeted(false)
            Task { @MainActor in
                FrameStripDragContext.draggedFrameIDs = []
            }
        }

        guard let resolvedTarget = resolvedTarget(for: info) else { return false }
        performMove(resolvedTarget)
        return true
    }

    private func resolvedTarget(for info: DropInfo) -> WorkspaceFrameDropTarget? {
        let movingFrameIDs = draggedFrameIDs()
        let movingFrameIDSet = Set(movingFrameIDs)
        guard movingFrameIDSet.isEmpty == false else { return nil }
        if let targetFrameID = target.targetFrameID, movingFrameIDSet.contains(targetFrameID) {
            return nil
        }

        let remainingFrameIDs = allFrameIDs.filter { movingFrameIDSet.contains($0) == false }
        let reorderedFrameIDs: [UUID]
        switch target.position {
        case .before:
            guard let targetFrameID = target.targetFrameID,
                  let targetIndex = remainingFrameIDs.firstIndex(of: targetFrameID) else { return nil }
            reorderedFrameIDs = Array(remainingFrameIDs[..<targetIndex]) + movingFrameIDs + Array(remainingFrameIDs[targetIndex...])
        case .after:
            guard let targetFrameID = target.targetFrameID,
                  let targetIndex = remainingFrameIDs.firstIndex(of: targetFrameID) else { return nil }
            reorderedFrameIDs = Array(remainingFrameIDs[...targetIndex]) + movingFrameIDs + Array(remainingFrameIDs[(targetIndex + 1)...])
        case .append:
            reorderedFrameIDs = remainingFrameIDs + movingFrameIDs
        }

        guard reorderedFrameIDs != allFrameIDs else { return nil }
        return target
    }
}
