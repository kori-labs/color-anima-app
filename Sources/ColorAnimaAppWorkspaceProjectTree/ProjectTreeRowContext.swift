import ColorAnimaAppWorkspaceApplication
import Foundation

package struct ProjectTreeRowSelectionContext {
    let selectedNodeID: UUID?
    let selectedNodeIDs: Set<UUID>
    let selectionAnchorNodeID: UUID?

    package init(
        selectedNodeID: UUID?,
        selectedNodeIDs: Set<UUID>,
        selectionAnchorNodeID: UUID?
    ) {
        self.selectedNodeID = selectedNodeID
        self.selectedNodeIDs = selectedNodeIDs
        self.selectionAnchorNodeID = selectionAnchorNodeID
    }
}

package struct ProjectTreeRowCallbacks {
    let onSelectNode: (UUID, WorkspaceSelectionModifiers) -> Void
    let onMoveTreeNodes: ([UUID], UUID, ProjectTreeDropPosition) -> Void
    let onStartRename: (WorkspaceProjectTreeNode) -> Void
    let onCommitRename: (UUID) -> Void
    let onCancelRename: () -> Void
    let onDeleteNode: (UUID) -> Void

    package init(
        onSelectNode: @escaping (UUID, WorkspaceSelectionModifiers) -> Void,
        onMoveTreeNodes: @escaping ([UUID], UUID, ProjectTreeDropPosition) -> Void,
        onStartRename: @escaping (WorkspaceProjectTreeNode) -> Void,
        onCommitRename: @escaping (UUID) -> Void,
        onCancelRename: @escaping () -> Void,
        onDeleteNode: @escaping (UUID) -> Void
    ) {
        self.onSelectNode = onSelectNode
        self.onMoveTreeNodes = onMoveTreeNodes
        self.onStartRename = onStartRename
        self.onCommitRename = onCommitRename
        self.onCancelRename = onCancelRename
        self.onDeleteNode = onDeleteNode
    }
}
