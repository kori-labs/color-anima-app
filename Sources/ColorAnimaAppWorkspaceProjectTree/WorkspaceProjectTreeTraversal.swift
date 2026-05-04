import ColorAnimaAppWorkspaceApplication
import Foundation

package enum WorkspaceProjectTreeTraversal {
    package static func treeNodePath(
        for nodeID: UUID,
        in node: WorkspaceProjectTreeNode,
        trail: [WorkspaceProjectTreeNode] = []
    ) -> [WorkspaceProjectTreeNode]? {
        let nextTrail = trail + [node]
        if node.id == nodeID {
            return nextTrail
        }
        for child in node.children {
            if let match = treeNodePath(for: nodeID, in: child, trail: nextTrail) {
                return match
            }
        }
        return nil
    }

    package static func treeSelectionKey(
        for nodeID: UUID,
        in rootNode: WorkspaceProjectTreeNode
    ) -> (kind: WorkspaceProjectTreeNodeKind, parentID: UUID?)? {
        guard let path = treeNodePath(for: nodeID, in: rootNode),
              let node = path.last else {
            return nil
        }

        return (node.kind, path.dropLast().last?.id)
    }

    package static func flattenNodeIDs(in node: WorkspaceProjectTreeNode) -> [UUID] {
        var result = [node.id]
        for child in node.children {
            result.append(contentsOf: flattenNodeIDs(in: child))
        }
        return result
    }

    package static func orderedNodeIDs(
        _ ids: Set<UUID>,
        in rootNode: WorkspaceProjectTreeNode
    ) -> [UUID] {
        flattenNodeIDs(in: rootNode).filter { ids.contains($0) }
    }

    package static func selectionRange(
        from anchorID: UUID,
        to nodeID: UUID,
        in rootNode: WorkspaceProjectTreeNode
    ) -> [UUID]? {
        guard let anchorKey = treeSelectionKey(for: anchorID, in: rootNode),
              let nodeKey = treeSelectionKey(for: nodeID, in: rootNode),
              anchorKey.kind == nodeKey.kind,
              anchorKey.parentID == nodeKey.parentID else {
            return nil
        }

        let siblingIDs: [UUID]
        switch anchorKey.parentID {
        case nil:
            siblingIDs = [rootNode.id]
        default:
            guard let parentPath = treeNodePath(for: anchorID, in: rootNode)?.dropLast(),
                  let parent = parentPath.last else {
                return nil
            }
            siblingIDs = parent.children.map(\.id)
        }

        guard let anchorIndex = siblingIDs.firstIndex(of: anchorID),
              let nodeIndex = siblingIDs.firstIndex(of: nodeID) else {
            return nil
        }

        let lower = min(anchorIndex, nodeIndex)
        let upper = max(anchorIndex, nodeIndex)
        return Array(siblingIDs[lower...upper])
    }
}
