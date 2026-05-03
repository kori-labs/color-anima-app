import ColorAnimaAppWorkspaceApplication
import Foundation

package enum ProjectTreeCollapsePolicy {
    package static func toggle(
        node: WorkspaceProjectTreeNode,
        selectedNodeIDs: Set<UUID>,
        collapsedNodeIDs: inout Set<UUID>,
        onSelectNode: (UUID, WorkspaceSelectionModifiers) -> Void
    ) {
        if collapsedNodeIDs.contains(node.id) {
            collapsedNodeIDs.remove(node.id)
            return
        }

        collapsedNodeIDs.insert(node.id)
        if containsSelectedDescendant(of: node, selectedNodeIDs: selectedNodeIDs) {
            onSelectNode(node.id, [])
        }
    }

    package static func containsSelectedDescendant(
        of node: WorkspaceProjectTreeNode,
        selectedNodeIDs: Set<UUID>
    ) -> Bool {
        node.children.contains(where: { containsSelectedNode(in: $0, selectedNodeIDs: selectedNodeIDs) })
    }

    private static func containsSelectedNode(
        in node: WorkspaceProjectTreeNode,
        selectedNodeIDs: Set<UUID>
    ) -> Bool {
        if selectedNodeIDs.contains(node.id) {
            return true
        }
        return node.children.contains(where: { containsSelectedNode(in: $0, selectedNodeIDs: selectedNodeIDs) })
    }
}
