import Foundation

enum ProjectColorSystemRefreshDispatcher {
    static func refreshScope(
        for role: WritableKeyPath<ColorRoles, RGBAColor>
    ) -> ProjectColorSystemRefreshScope {
        if role == \.base {
            return .overlay
        }
        if role == \.highlight {
            return .highlightGuide
        }
        return .shadowGuide
    }

    static func refreshScope(
        for keyPath: WritableKeyPath<ColorSystemSubset, Bool>
    ) -> ProjectColorSystemRefreshScope {
        keyPath == \.isHighlightEnabled ? .highlightGuide : .shadowGuide
    }

    static func workspaceUsesEditedSubset(
        _ workspace: ProjectColorSystemWorkspaceUsageState,
        editedSubsetID: UUID
    ) -> Bool {
        workspace.subsetIDsByFrameID.values.contains { $0.contains(editedSubsetID) }
    }

    static func affectedInactiveFrameIDsSplit(
        in workspace: ProjectColorSystemWorkspaceUsageState,
        editedSubsetID: UUID
    ) -> (adjacent: [UUID], rest: [UUID]) {
        let frames = workspace.frameIDsInDisplayOrder
        guard let selectedFrameID = workspace.selectedFrameID,
              let activeIndex = frames.firstIndex(of: selectedFrameID) else {
            return (adjacent: [], rest: [])
        }

        func containsEditedSubset(_ frameID: UUID) -> Bool {
            workspace.subsetIDsByFrameID[frameID]?.contains(editedSubsetID) == true
        }

        var adjacentIDs: [UUID] = []
        if activeIndex > 0 {
            let previous = frames[activeIndex - 1]
            if containsEditedSubset(previous) {
                adjacentIDs.append(previous)
            }
        }
        if activeIndex < frames.count - 1 {
            let next = frames[activeIndex + 1]
            if containsEditedSubset(next) {
                adjacentIDs.append(next)
            }
        }

        let adjacentSet = Set(adjacentIDs)
        let rest = frames.compactMap { frameID -> UUID? in
            guard frameID != selectedFrameID else { return nil }
            guard adjacentSet.contains(frameID) == false else { return nil }
            return containsEditedSubset(frameID) ? frameID : nil
        }

        return (adjacent: adjacentIDs, rest: rest)
    }

    static func applyColorSystemEditRefresh(
        scope: ProjectColorSystemRefreshScope,
        editedSubsetID: UUID,
        in state: inout ProjectColorSystemEditingState
    ) {
        let inactiveCutIDs = state.workspaces.keys
            .filter { $0 != state.activeCutID }
            .sorted { $0.uuidString < $1.uuidString }
            .filter { cutID in
                guard let workspace = state.workspaces[cutID] else { return false }
                return workspaceUsesEditedSubset(workspace, editedSubsetID: editedSubsetID)
            }

        let split: (adjacent: [UUID], rest: [UUID])
        if let activeCutID = state.activeCutID,
           let workspace = state.workspaces[activeCutID] {
            split = affectedInactiveFrameIDsSplit(in: workspace, editedSubsetID: editedSubsetID)
        } else {
            split = (adjacent: [], rest: [])
        }

        state.needsColorSystemRefresh = true
        state.refreshRequests.append(
            ProjectColorSystemEditRefreshRequest(
                scope: scope,
                editedSubsetID: editedSubsetID,
                activeCutID: state.activeCutID,
                inactiveCutIDs: inactiveCutIDs,
                prewarmAdjacentFrameIDs: split.adjacent,
                prewarmRestFrameIDs: split.rest
            )
        )
    }
}
