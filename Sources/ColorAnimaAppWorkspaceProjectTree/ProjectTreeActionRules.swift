import ColorAnimaAppWorkspaceApplication
import Foundation

package enum ProjectTreeActionRules {
    enum PrimaryCreateKind: Equatable {
        case sequence
        case scene(UUID)
        case cut(UUID)
        case disabled
    }

    struct PrimaryCreateAction: Equatable {
        let title: String
        let systemImage: String
        let kind: PrimaryCreateKind

        var isEnabled: Bool {
            kind != .disabled
        }

        var nounLabel: String {
            switch kind {
            case .sequence:
                return "Sequence"
            case .scene:
                return "Scene"
            case .cut:
                return "Cut"
            case .disabled:
                return "—"
            }
        }
    }

    struct ExperimentalCreateActions: Equatable {
        let outer: PrimaryCreateAction
        let inner: PrimaryCreateAction

        var isEnabled: Bool {
            outer.isEnabled || inner.isEnabled
        }
    }

    static func canCreateSequence(from selectedNode: WorkspaceProjectTreeNode?) -> Bool {
        selectedNode?.kind == .project
    }

    static func canCreateScene(from selectedNode: WorkspaceProjectTreeNode?) -> Bool {
        selectedNode?.kind == .sequence
    }

    static func canCreateCut(from selectedNode: WorkspaceProjectTreeNode?) -> Bool {
        guard let kind = selectedNode?.kind else { return false }
        return kind == .scene || kind == .cut
    }

    static func primaryCreateAction(
        selectedNodeID: UUID?,
        selectedNode: WorkspaceProjectTreeNode?,
        rootNode: WorkspaceProjectTreeNode
    ) -> PrimaryCreateAction {
        switch selectedNode?.kind {
        case .sequence:
            guard let selectedNode else {
                return PrimaryCreateAction(title: "New Scene", systemImage: "square.stack", kind: .disabled)
            }
            return PrimaryCreateAction(
                title: "New Scene",
                systemImage: "square.stack",
                kind: .scene(selectedNode.id)
            )
        case .scene:
            guard let selectedNode else {
                return PrimaryCreateAction(title: "New Cut", systemImage: "film", kind: .disabled)
            }
            return PrimaryCreateAction(
                title: "New Cut",
                systemImage: "film",
                kind: .cut(selectedNode.id)
            )
        case .cut:
            guard let sceneID = cutCreationTargetSceneID(
                selectedNodeID: selectedNodeID,
                selectedNode: selectedNode,
                rootNode: rootNode
            ) else {
                return PrimaryCreateAction(title: "New Cut", systemImage: "film", kind: .disabled)
            }
            return PrimaryCreateAction(
                title: "New Cut",
                systemImage: "film",
                kind: .cut(sceneID)
            )
        case .project, nil:
            return PrimaryCreateAction(
                title: "New Sequence",
                systemImage: "folder.badge.plus",
                kind: .sequence
            )
        }
    }

    static func experimentalCreateActions(
        selectedNodeID: UUID?,
        selectedNode: WorkspaceProjectTreeNode?,
        rootNode: WorkspaceProjectTreeNode
    ) -> ExperimentalCreateActions {
        switch selectedNode?.kind {
        case .sequence:
            guard let selectedNode else {
                return disabledExperimentalCreateActions()
            }
            return ExperimentalCreateActions(
                outer: PrimaryCreateAction(
                    title: "New Sequence",
                    systemImage: "folder.badge.plus",
                    kind: .sequence
                ),
                inner: PrimaryCreateAction(
                    title: "New Scene",
                    systemImage: "square.stack",
                    kind: .scene(selectedNode.id)
                )
            )
        case .scene:
            guard let sequenceID = sceneCreationTargetSequenceID(
                selectedNodeID: selectedNodeID,
                selectedNode: selectedNode,
                rootNode: rootNode
            ), let selectedNode else {
                return disabledExperimentalCreateActions()
            }
            return ExperimentalCreateActions(
                outer: PrimaryCreateAction(
                    title: "New Scene",
                    systemImage: "square.stack",
                    kind: .scene(sequenceID)
                ),
                inner: PrimaryCreateAction(
                    title: "New Cut",
                    systemImage: "film",
                    kind: .cut(selectedNode.id)
                )
            )
        case .cut:
            guard let sceneID = cutCreationTargetSceneID(
                selectedNodeID: selectedNodeID,
                selectedNode: selectedNode,
                rootNode: rootNode
            ) else {
                return disabledExperimentalCreateActions()
            }
            let cutAction = PrimaryCreateAction(
                title: "New Cut",
                systemImage: "film",
                kind: .cut(sceneID)
            )
            return ExperimentalCreateActions(outer: cutAction, inner: cutAction)
        case .project, nil:
            return disabledExperimentalCreateActions()
        }
    }

    static func cutCreationTargetSceneID(
        selectedNodeID: UUID?,
        selectedNode: WorkspaceProjectTreeNode?,
        rootNode: WorkspaceProjectTreeNode
    ) -> UUID? {
        guard let selectedNodeID, let selectedNode, canCreateCut(from: selectedNode) else { return nil }
        guard let path = nodePath(for: selectedNodeID, in: rootNode) else { return nil }
        return path.last(where: { $0.kind == .scene })?.id
    }

    static func sceneCreationTargetSequenceID(
        selectedNodeID: UUID?,
        selectedNode: WorkspaceProjectTreeNode?,
        rootNode: WorkspaceProjectTreeNode
    ) -> UUID? {
        guard let selectedNodeID, selectedNode?.kind == .scene else { return nil }
        guard let path = nodePath(for: selectedNodeID, in: rootNode) else { return nil }
        return path.last(where: { $0.kind == .sequence })?.id
    }

    private static func disabledExperimentalCreateActions() -> ExperimentalCreateActions {
        ExperimentalCreateActions(
            outer: PrimaryCreateAction(title: "Add Sibling", systemImage: "circle", kind: .disabled),
            inner: PrimaryCreateAction(title: "Add Child", systemImage: "circle.fill", kind: .disabled)
        )
    }

    static func nodePath(
        for nodeID: UUID,
        in node: WorkspaceProjectTreeNode,
        trail: [WorkspaceProjectTreeNode] = []
    ) -> [WorkspaceProjectTreeNode]? {
        let nextTrail = trail + [node]
        if node.id == nodeID {
            return nextTrail
        }
        for child in node.children {
            if let match = nodePath(for: nodeID, in: child, trail: nextTrail) {
                return match
            }
        }
        return nil
    }

    static func treeSelectionKey(
        for nodeID: UUID,
        in rootNode: WorkspaceProjectTreeNode
    ) -> (kind: WorkspaceProjectTreeNodeKind, parentID: UUID?)? {
        guard let path = nodePath(for: nodeID, in: rootNode),
              let node = path.last else {
            return nil
        }

        return (node.kind, path.dropLast().last?.id)
    }

    static func orderedSelectionIDs(
        _ nodeIDs: Set<UUID>,
        in rootNode: WorkspaceProjectTreeNode
    ) -> [UUID] {
        flattenNodeIDs(in: rootNode).filter { nodeIDs.contains($0) }
    }

    static func selectionRange(
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
            guard let parentPath = nodePath(for: anchorID, in: rootNode)?.dropLast(),
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

    static func canMoveSelection(
        _ nodeIDs: Set<UUID>,
        to targetNodeID: UUID,
        position: ProjectTreeDropPosition,
        in rootNode: WorkspaceProjectTreeNode
    ) -> Bool {
        let orderedNodeIDs = orderedSelectionIDs(nodeIDs, in: rootNode)
        guard !orderedNodeIDs.isEmpty else { return false }
        guard nodeIDs.contains(targetNodeID) == false else { return false }
        guard let movingKey = treeSelectionKey(for: orderedNodeIDs.first!, in: rootNode) else { return false }
        guard orderedNodeIDs.allSatisfy({
            treeSelectionKey(for: $0, in: rootNode)?.kind == movingKey.kind &&
            treeSelectionKey(for: $0, in: rootNode)?.parentID == movingKey.parentID
        }) else { return false }

        guard let targetKey = treeSelectionKey(for: targetNodeID, in: rootNode) else { return false }

        switch movingKey.kind {
        case .sequence:
            switch targetKey.kind {
            case .sequence:
                return position != .append
            case .project:
                return position == .append
            case .scene, .cut:
                return false
            }
        case .scene:
            switch targetKey.kind {
            case .sequence:
                return position == .append
            case .scene:
                return position != .append
            case .project, .cut:
                return false
            }
        case .cut:
            switch targetKey.kind {
            case .scene:
                return position == .append
            case .cut:
                return position != .append
            case .project, .sequence:
                return false
            }
        case .project:
            return false
        }
    }

    private static func flattenNodeIDs(in node: WorkspaceProjectTreeNode) -> [UUID] {
        var result = [node.id]
        for child in node.children {
            result.append(contentsOf: flattenNodeIDs(in: child))
        }
        return result
    }
}
