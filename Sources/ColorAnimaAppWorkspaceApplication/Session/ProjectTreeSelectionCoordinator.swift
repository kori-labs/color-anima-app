import Foundation

public struct ProjectTreeSelectionKey: Equatable, Sendable {
    public var kind: WorkspaceProjectTreeNodeKind
    public var parentID: UUID?

    public init(kind: WorkspaceProjectTreeNodeKind, parentID: UUID?) {
        self.kind = kind
        self.parentID = parentID
    }
}

public struct ProjectTreeSelectionState: Equatable, Sendable {
    public var rootNode: WorkspaceProjectTreeNode
    public var selectedNodeID: UUID?
    public var selectedNodeIDs: Set<UUID>
    public var selectionAnchorNodeID: UUID?
    public var activeCutID: UUID?
    public var lastOpenedCutID: UUID?
    public var framePlaybackCutID: UUID?
    public var dirtyCutIDs: Set<UUID>
    public var frameSelectionMemory: ProjectFrameSelectionMemoryState
    public var didRequestFramePlaybackStop: Bool
    public var didRequestActiveCutRefresh: Bool
    public var workspaceLoadRequestCutID: UUID?

    public init(
        rootNode: WorkspaceProjectTreeNode,
        selectedNodeID: UUID? = nil,
        selectedNodeIDs: Set<UUID> = [],
        selectionAnchorNodeID: UUID? = nil,
        activeCutID: UUID? = nil,
        lastOpenedCutID: UUID? = nil,
        framePlaybackCutID: UUID? = nil,
        dirtyCutIDs: Set<UUID> = [],
        frameSelectionMemory: ProjectFrameSelectionMemoryState = ProjectFrameSelectionMemoryState(),
        didRequestFramePlaybackStop: Bool = false,
        didRequestActiveCutRefresh: Bool = false,
        workspaceLoadRequestCutID: UUID? = nil
    ) {
        self.rootNode = rootNode
        self.selectedNodeID = selectedNodeID
        self.selectedNodeIDs = selectedNodeIDs
        self.selectionAnchorNodeID = selectionAnchorNodeID
        self.activeCutID = activeCutID
        self.lastOpenedCutID = lastOpenedCutID
        self.framePlaybackCutID = framePlaybackCutID
        self.dirtyCutIDs = dirtyCutIDs
        self.frameSelectionMemory = frameSelectionMemory
        self.didRequestFramePlaybackStop = didRequestFramePlaybackStop
        self.didRequestActiveCutRefresh = didRequestActiveCutRefresh
        self.workspaceLoadRequestCutID = workspaceLoadRequestCutID
    }
}

public enum ProjectTreeSelectionCoordinator {
    public static func findNode(
        id: UUID,
        in node: WorkspaceProjectTreeNode
    ) -> WorkspaceProjectTreeNode? {
        if node.id == id {
            return node
        }
        for child in node.children {
            if let match = findNode(id: id, in: child) {
                return match
            }
        }
        return nil
    }

    public static func treeNodePath(
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

    public static func selectionKind(
        for nodeID: UUID,
        in rootNode: WorkspaceProjectTreeNode
    ) -> WorkspaceProjectTreeNodeKind? {
        findNode(id: nodeID, in: rootNode)?.kind
    }

    public static func treeSelectionKey(
        for nodeID: UUID?,
        in rootNode: WorkspaceProjectTreeNode
    ) -> ProjectTreeSelectionKey? {
        guard let nodeID,
              let path = treeNodePath(for: nodeID, in: rootNode),
              let node = path.last else {
            return nil
        }
        return ProjectTreeSelectionKey(kind: node.kind, parentID: path.dropLast().last?.id)
    }

    public static func siblingNodeIDs(
        for nodeID: UUID,
        in rootNode: WorkspaceProjectTreeNode
    ) -> [UUID]? {
        guard let key = treeSelectionKey(for: nodeID, in: rootNode) else { return nil }
        if key.parentID == nil {
            return [rootNode.id]
        }
        guard let path = treeNodePath(for: nodeID, in: rootNode),
              let parent = path.dropLast().last else {
            return nil
        }
        return parent.children.map(\.id)
    }

    public static func selectionRange(
        from anchorID: UUID,
        to nodeID: UUID,
        in rootNode: WorkspaceProjectTreeNode
    ) -> [UUID]? {
        guard let anchorKey = treeSelectionKey(for: anchorID, in: rootNode),
              let nodeKey = treeSelectionKey(for: nodeID, in: rootNode),
              anchorKey == nodeKey,
              let siblingIDs = siblingNodeIDs(for: anchorID, in: rootNode),
              let anchorIndex = siblingIDs.firstIndex(of: anchorID),
              let nodeIndex = siblingIDs.firstIndex(of: nodeID) else {
            return nil
        }

        let lowerBound = min(anchorIndex, nodeIndex)
        let upperBound = max(anchorIndex, nodeIndex)
        return Array(siblingIDs[lowerBound ... upperBound])
    }

    public static func orderedTreeSelectionIDs(
        in selection: Set<UUID>,
        rootNode: WorkspaceProjectTreeNode
    ) -> [UUID] {
        flattenNodeIDs(in: rootNode).filter { selection.contains($0) }
    }

    public static func selectNode(
        _ nodeID: UUID,
        modifiers: WorkspaceSelectionModifiers = [],
        in state: inout ProjectTreeSelectionState
    ) {
        guard selectionKind(for: nodeID, in: state.rootNode) != nil else { return }

        if modifiers.contains(.range),
           let anchorID = state.selectionAnchorNodeID,
           let range = selectionRange(from: anchorID, to: nodeID, in: state.rootNode),
           range.isEmpty == false {
            applyNodeSelection(selectedIDs: Set(range), primaryID: nodeID, anchorID: anchorID, in: &state)
            return
        }

        if modifiers.contains(.additive) {
            let currentSelection = state.selectedNodeIDs.filter {
                selectionKind(for: $0, in: state.rootNode) != nil
            }

            if let currentKey = treeSelectionKey(for: state.selectedNodeID, in: state.rootNode),
               let nextKey = treeSelectionKey(for: nodeID, in: state.rootNode),
               currentSelection.isEmpty == false,
               currentKey != nextKey {
                applyNodeSelection(selectedIDs: [nodeID], primaryID: nodeID, anchorID: nodeID, in: &state)
                return
            }

            var nextSelection = currentSelection
            if nextSelection.contains(nodeID) {
                if nextSelection.count == 1 {
                    applyNodeSelection(selectedIDs: [nodeID], primaryID: nodeID, anchorID: nodeID, in: &state)
                    return
                }

                nextSelection.remove(nodeID)
                let orderedRemaining = orderedTreeSelectionIDs(in: nextSelection, rootNode: state.rootNode)
                let nextPrimaryID = state.selectedNodeID.flatMap {
                    nextSelection.contains($0) ? $0 : nil
                } ?? orderedRemaining.first
                let nextAnchorID = state.selectionAnchorNodeID.flatMap {
                    nextSelection.contains($0) ? $0 : nil
                } ?? nextPrimaryID
                applyNodeSelection(
                    selectedIDs: nextSelection,
                    primaryID: nextPrimaryID,
                    anchorID: nextAnchorID,
                    in: &state
                )
                return
            }

            nextSelection.insert(nodeID)
            applyNodeSelection(selectedIDs: nextSelection, primaryID: nodeID, anchorID: nodeID, in: &state)
            return
        }

        applyNodeSelection(selectedIDs: [nodeID], primaryID: nodeID, anchorID: nodeID, in: &state)
    }

    public static func applyNodeSelection(
        selectedIDs: Set<UUID>,
        primaryID: UUID?,
        anchorID: UUID?,
        in state: inout ProjectTreeSelectionState
    ) {
        let validSelectedIDs = selectedIDs.filter { selectionKind(for: $0, in: state.rootNode) != nil }
        let orderedSelectedIDs = orderedTreeSelectionIDs(in: validSelectedIDs, rootNode: state.rootNode)
        let resolvedPrimaryID = primaryID.flatMap { validSelectedIDs.contains($0) ? $0 : nil }
            ?? orderedSelectedIDs.first
        let resolvedAnchorID = anchorID.flatMap { validSelectedIDs.contains($0) ? $0 : nil }
            ?? resolvedPrimaryID

        state.selectedNodeIDs = validSelectedIDs
        state.selectedNodeID = resolvedPrimaryID
        state.selectionAnchorNodeID = resolvedAnchorID

        if state.framePlaybackCutID != resolvedPrimaryID {
            state.framePlaybackCutID = nil
            state.didRequestFramePlaybackStop = true
        }

        guard let resolvedPrimaryID,
              selectionKind(for: resolvedPrimaryID, in: state.rootNode) == .cut else {
            state.activeCutID = nil
            state.workspaceLoadRequestCutID = nil
            state.didRequestActiveCutRefresh = true
            return
        }

        state.activeCutID = resolvedPrimaryID
        state.lastOpenedCutID = resolvedPrimaryID
        state.workspaceLoadRequestCutID = resolvedPrimaryID
        syncFrameSelectionMemory(for: resolvedPrimaryID, in: &state)
        state.didRequestActiveCutRefresh = true
    }

    public static func normalizeSelectionAfterStructureChange(
        in state: inout ProjectTreeSelectionState
    ) {
        let validSelectionIDs = state.selectedNodeIDs.filter {
            selectionKind(for: $0, in: state.rootNode) != nil
        }

        if let selectedNodeID = state.selectedNodeID,
           selectionKind(for: selectedNodeID, in: state.rootNode) != nil {
            let anchorID = state.selectionAnchorNodeID.flatMap {
                validSelectionIDs.contains($0) ? $0 : nil
            }
            state.selectedNodeIDs = (validSelectionIDs.isEmpty ? [selectedNodeID] : validSelectionIDs)
                .union([selectedNodeID])
            state.selectionAnchorNodeID = anchorID ?? selectedNodeID
            if selectionKind(for: selectedNodeID, in: state.rootNode) == .cut {
                state.activeCutID = selectedNodeID
                state.lastOpenedCutID = selectedNodeID
            }
            return
        }

        if let firstSelectedID = orderedTreeSelectionIDs(in: validSelectionIDs, rootNode: state.rootNode).first {
            applyNodeSelection(
                selectedIDs: validSelectionIDs.isEmpty ? [firstSelectedID] : validSelectionIDs,
                primaryID: firstSelectedID,
                anchorID: state.selectionAnchorNodeID.flatMap {
                    validSelectionIDs.contains($0) ? $0 : nil
                } ?? firstSelectedID,
                in: &state
            )
            return
        }

        if let firstCutID = state.rootNode.firstCutID {
            selectNode(firstCutID, in: &state)
            return
        }

        state.activeCutID = nil
        state.selectedNodeID = state.rootNode.id
        state.selectedNodeIDs = [state.rootNode.id]
        state.selectionAnchorNodeID = state.rootNode.id
    }

    public static func cutIDsRemovingNode(
        _ nodeID: UUID,
        kind: WorkspaceProjectTreeNodeKind,
        in rootNode: WorkspaceProjectTreeNode
    ) -> [UUID] {
        switch kind {
        case .project:
            return rootNode.allCutIDs
        case .sequence, .scene:
            return findNode(id: nodeID, in: rootNode)?.allCutIDs ?? []
        case .cut:
            return [nodeID]
        }
    }

    public static func pruneStaleCutState(in state: inout ProjectTreeSelectionState) {
        let validCutIDs = Set(state.rootNode.allCutIDs)
        state.frameSelectionMemory.workspaces = state.frameSelectionMemory.workspaces.filter { cutID, _ in
            validCutIDs.contains(cutID)
        }
        state.frameSelectionMemory.selectedFrameIDByCutID = state.frameSelectionMemory.selectedFrameIDByCutID.filter { cutID, _ in
            validCutIDs.contains(cutID)
        }
        state.frameSelectionMemory.selectedFrameIDsByCutID = state.frameSelectionMemory.selectedFrameIDsByCutID.filter { cutID, _ in
            validCutIDs.contains(cutID)
        }
        state.frameSelectionMemory.frameSelectionAnchorByCutID = state.frameSelectionMemory.frameSelectionAnchorByCutID.filter { cutID, _ in
            validCutIDs.contains(cutID)
        }
        state.frameSelectionMemory.selectedFrameSelectionOrderByCutID = state.frameSelectionMemory.selectedFrameSelectionOrderByCutID.filter { cutID, _ in
            validCutIDs.contains(cutID)
        }
        state.dirtyCutIDs = Set(state.dirtyCutIDs.filter { validCutIDs.contains($0) })

        if let activeCutID = state.activeCutID,
           validCutIDs.contains(activeCutID) == false {
            if state.framePlaybackCutID == activeCutID {
                state.framePlaybackCutID = nil
                state.didRequestFramePlaybackStop = true
            }
            state.activeCutID = nil
        }

        if let lastOpenedCutID = state.lastOpenedCutID,
           validCutIDs.contains(lastOpenedCutID) == false {
            state.lastOpenedCutID = state.rootNode.firstCutID
        }

        if let selectedNodeID = state.selectedNodeID,
           selectionKind(for: selectedNodeID, in: state.rootNode) == nil {
            normalizeSelectionAfterStructureChange(in: &state)
        }

        state.selectedNodeIDs = state.selectedNodeIDs.filter {
            selectionKind(for: $0, in: state.rootNode) != nil
        }
        if state.selectedNodeIDs.isEmpty,
           let selectedNodeID = state.selectedNodeID,
           selectionKind(for: selectedNodeID, in: state.rootNode) != nil {
            state.selectedNodeIDs.insert(selectedNodeID)
        }
        if state.selectionAnchorNodeID.map({ selectionKind(for: $0, in: state.rootNode) == nil }) == true {
            state.selectionAnchorNodeID = orderedTreeSelectionIDs(
                in: state.selectedNodeIDs,
                rootNode: state.rootNode
            ).first
        }

        for (cutID, selection) in state.frameSelectionMemory.selectedFrameIDsByCutID {
            let validFrameIDs = Set(
                state.frameSelectionMemory.workspaces[cutID]?.frameIDsInDisplayOrder ?? []
            )
            let filteredSelection = selection.filter { validFrameIDs.contains($0) }

            if filteredSelection.isEmpty {
                state.frameSelectionMemory.selectedFrameIDsByCutID.removeValue(forKey: cutID)
                state.frameSelectionMemory.frameSelectionAnchorByCutID.removeValue(forKey: cutID)
                state.frameSelectionMemory.selectedFrameSelectionOrderByCutID.removeValue(forKey: cutID)
                continue
            }

            state.frameSelectionMemory.selectedFrameIDsByCutID[cutID] = filteredSelection
            if let selectedFrameID = state.frameSelectionMemory.selectedFrameIDByCutID[cutID],
               filteredSelection.contains(selectedFrameID) == false {
                state.frameSelectionMemory.selectedFrameIDByCutID[cutID] =
                    ProjectFrameSelectionMemoryCoordinator.orderedFrameSelectionIDs(
                        in: filteredSelection,
                        for: cutID,
                        in: state.frameSelectionMemory
                    ).first
            }
            if let anchorID = state.frameSelectionMemory.frameSelectionAnchorByCutID[cutID],
               validFrameIDs.contains(anchorID) == false {
                state.frameSelectionMemory.frameSelectionAnchorByCutID[cutID] =
                    ProjectFrameSelectionMemoryCoordinator.orderedFrameSelectionIDs(
                        in: filteredSelection,
                        for: cutID,
                        in: state.frameSelectionMemory
                    ).first
            }
            state.frameSelectionMemory.selectedFrameSelectionOrderByCutID[cutID] =
                ProjectFrameSelectionMemoryCoordinator.normalizedFrameSelectionOrder(
                    selection: filteredSelection,
                    frameIDsInDisplayOrder: ProjectFrameSelectionMemoryCoordinator.orderedFrameIDs(
                        for: cutID,
                        in: state.frameSelectionMemory
                    ),
                    preferredOrder: state.frameSelectionMemory.selectedFrameSelectionOrderByCutID[cutID],
                    primaryID: state.frameSelectionMemory.selectedFrameIDByCutID[cutID]
                )
        }
    }

    private static func flattenNodeIDs(in node: WorkspaceProjectTreeNode) -> [UUID] {
        var result = [node.id]
        for child in node.children {
            result.append(contentsOf: flattenNodeIDs(in: child))
        }
        return result
    }

    private static func syncFrameSelectionMemory(
        for cutID: UUID,
        in state: inout ProjectTreeSelectionState
    ) {
        guard let workspace = state.frameSelectionMemory.workspaces[cutID] else { return }
        ProjectFrameSelectionMemoryCoordinator.syncFrameSelectionState(
            for: cutID,
            workspace: workspace,
            in: &state.frameSelectionMemory
        )
    }
}
