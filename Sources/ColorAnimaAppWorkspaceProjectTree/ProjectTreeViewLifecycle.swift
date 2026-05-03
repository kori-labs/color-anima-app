import ColorAnimaAppWorkspaceApplication
import Foundation

@MainActor
package protocol ProjectTreeViewLifecycleManaging {
    func synchronizeTreeState(
        _ viewState: inout ProjectTreeViewState,
        rootNode: WorkspaceProjectTreeNode,
        selectedNodeID: UUID?,
        selectedNodeIDs: Set<UUID>,
        selectionAnchorNodeID: UUID?
    )

    func synchronizeSelectionState(
        _ viewState: inout ProjectTreeViewState,
        rootNode: WorkspaceProjectTreeNode,
        selectedNodeID: UUID?,
        selectedNodeIDs: Set<UUID>,
        selectionAnchorNodeID: UUID?
    )
}

@MainActor
package struct ProjectTreeViewLifecycle: ProjectTreeViewLifecycleManaging {
    package init() {}

    package func synchronizeTreeState(
        _ viewState: inout ProjectTreeViewState,
        rootNode: WorkspaceProjectTreeNode,
        selectedNodeID: UUID?,
        selectedNodeIDs: Set<UUID>,
        selectionAnchorNodeID: UUID?
    ) {
        viewState.pruneCollapsedNodes(in: rootNode)
        viewState.expandSelectedPath(
            in: rootNode,
            selectedNodeID: selectedNodeID,
            selectedNodeIDs: selectedNodeIDs
        )
    }

    package func synchronizeSelectionState(
        _ viewState: inout ProjectTreeViewState,
        rootNode: WorkspaceProjectTreeNode,
        selectedNodeID: UUID?,
        selectedNodeIDs: Set<UUID>,
        selectionAnchorNodeID: UUID?
    ) {
        viewState.expandSelectedPath(
            in: rootNode,
            selectedNodeID: selectedNodeID,
            selectedNodeIDs: selectedNodeIDs
        )
        viewState.cancelNodeRenameIfSelectionChanged(
            selectedNodeID: selectedNodeID,
            selectedNodeIDs: selectedNodeIDs
        )
    }
}
