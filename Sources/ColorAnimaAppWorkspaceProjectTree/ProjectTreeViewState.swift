import ColorAnimaAppWorkspaceApplication
import Foundation

package struct ProjectTreeViewState: Equatable {
    var collapsedNodeIDs: Set<UUID> = []
    var editingNodeID: UUID?
    var editingNodeName = ""
    var draggedNodeIDs: Set<UUID> = []
    var dropTargetNodeID: UUID?
    var dropTargetPosition: ProjectTreeDropPosition?

    mutating func pruneCollapsedNodes(in rootNode: WorkspaceProjectTreeNode) {
        // Skip the full tree traversal when nothing is collapsed — the common
        // case during initial tree display and after a full drag-clear.
        guard !collapsedNodeIDs.isEmpty else { return }
        let validCollapsedNodeIDs = Set(collapsibleNodeIDs(in: rootNode))
        collapsedNodeIDs.formIntersection(validCollapsedNodeIDs)
    }

    mutating func expandSelectedPath(
        in rootNode: WorkspaceProjectTreeNode,
        selectedNodeID: UUID?,
        selectedNodeIDs: Set<UUID>
    ) {
        guard let selectedNodeID,
              let path = ProjectTreeActionRules.nodePath(for: selectedNodeID, in: rootNode) else {
            return
        }

        if selectedNodeIDs.contains(selectedNodeID) == false {
            return
        }

        collapsedNodeIDs.subtract(path.map(\.id))
    }

    mutating func startNodeRename(
        _ node: WorkspaceProjectTreeNode,
        onSelectNode: (UUID) -> Void
    ) {
        onSelectNode(node.id)
        editingNodeID = node.id
        editingNodeName = node.name
    }

    mutating func commitNodeRename(
        _ nodeID: UUID,
        onRenameNode: (UUID, String) -> Void
    ) {
        defer {
            cancelNodeRename()
        }

        let trimmedName = editingNodeName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        onRenameNode(nodeID, trimmedName)
    }

    mutating func cancelNodeRename() {
        editingNodeID = nil
        editingNodeName = ""
    }

    mutating func cancelNodeRenameIfSelectionChanged(selectedNodeID: UUID?, selectedNodeIDs: Set<UUID>) {
        guard let editingNodeID else {
            return
        }
        guard selectedNodeIDs.contains(editingNodeID) else {
            cancelNodeRename()
            return
        }
        guard editingNodeID == selectedNodeID else {
            cancelNodeRename()
            return
        }
    }

    mutating func beginDrag(nodeID: UUID, selection: Set<UUID>) {
        draggedNodeIDs = selection.isEmpty ? [nodeID] : selection
    }

    mutating func clearDragState() {
        draggedNodeIDs.removeAll()
        dropTargetNodeID = nil
        dropTargetPosition = nil
    }

    mutating func setDropTarget(nodeID: UUID?, position: ProjectTreeDropPosition?) {
        dropTargetNodeID = nodeID
        dropTargetPosition = position
    }

    mutating func cancelNodeRenameIfSelectionChanged(selectedNodeID: UUID?) {
        guard editingNodeID != selectedNodeID else { return }
        cancelNodeRename()
    }

    private func collapsibleNodeIDs(in node: WorkspaceProjectTreeNode) -> [UUID] {
        var result: [UUID] = node.children.isEmpty ? [] : [node.id]
        for child in node.children {
            result.append(contentsOf: collapsibleNodeIDs(in: child))
        }
        return result
    }
}
