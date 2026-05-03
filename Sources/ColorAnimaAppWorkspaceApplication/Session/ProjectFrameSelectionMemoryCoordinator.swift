import Foundation

public struct ProjectFrameSelectionMemoryWorkspaceState: Hashable, Equatable, Sendable {
    public var frameIDsInDisplayOrder: [UUID]
    public var selectedFrameID: UUID?
    public var selectedFrameIDs: Set<UUID>
    public var selectedFrameSelectionAnchorID: UUID?

    public init(
        frameIDsInDisplayOrder: [UUID] = [],
        selectedFrameID: UUID? = nil,
        selectedFrameIDs: Set<UUID> = [],
        selectedFrameSelectionAnchorID: UUID? = nil
    ) {
        self.frameIDsInDisplayOrder = frameIDsInDisplayOrder
        self.selectedFrameID = selectedFrameID
        self.selectedFrameIDs = selectedFrameIDs
        self.selectedFrameSelectionAnchorID = selectedFrameSelectionAnchorID
    }
}

public struct ProjectFrameSelectionMemoryState: Hashable, Equatable, Sendable {
    public var workspaces: [UUID: ProjectFrameSelectionMemoryWorkspaceState]
    public var selectedFrameIDByCutID: [UUID: UUID]
    public var selectedFrameIDsByCutID: [UUID: Set<UUID>]
    public var frameSelectionAnchorByCutID: [UUID: UUID]
    public var selectedFrameSelectionOrderByCutID: [UUID: [UUID]]

    public init(
        workspaces: [UUID: ProjectFrameSelectionMemoryWorkspaceState] = [:],
        selectedFrameIDByCutID: [UUID: UUID] = [:],
        selectedFrameIDsByCutID: [UUID: Set<UUID>] = [:],
        frameSelectionAnchorByCutID: [UUID: UUID] = [:],
        selectedFrameSelectionOrderByCutID: [UUID: [UUID]] = [:]
    ) {
        self.workspaces = workspaces
        self.selectedFrameIDByCutID = selectedFrameIDByCutID
        self.selectedFrameIDsByCutID = selectedFrameIDsByCutID
        self.frameSelectionAnchorByCutID = frameSelectionAnchorByCutID
        self.selectedFrameSelectionOrderByCutID = selectedFrameSelectionOrderByCutID
    }
}

public enum ProjectFrameSelectionMemoryCoordinator {
    public static func orderedSelectedFrameIDs(
        for cutID: UUID,
        selection: Set<UUID>,
        primaryID: UUID?,
        in state: ProjectFrameSelectionMemoryState
    ) -> [UUID] {
        normalizedFrameSelectionOrder(
            selection: normalizedFrameSelectionSet(selection, primaryID: primaryID),
            frameIDsInDisplayOrder: orderedFrameIDs(for: cutID, in: state),
            preferredOrder: state.selectedFrameSelectionOrderByCutID[cutID],
            primaryID: primaryID
        )
    }

    public static func syncFrameSelectionState(
        for cutID: UUID,
        workspace: ProjectFrameSelectionMemoryWorkspaceState,
        preferredOrder: [UUID]? = nil,
        in state: inout ProjectFrameSelectionMemoryState
    ) {
        if let selectedFrameID = workspace.selectedFrameID {
            state.selectedFrameIDByCutID[cutID] = selectedFrameID
        } else {
            state.selectedFrameIDByCutID.removeValue(forKey: cutID)
        }

        let normalizedSelection = normalizedFrameSelectionSet(
            workspace.selectedFrameIDs,
            primaryID: workspace.selectedFrameID
        )

        if normalizedSelection.isEmpty == false {
            state.selectedFrameIDsByCutID[cutID] = normalizedSelection
            state.selectedFrameSelectionOrderByCutID[cutID] = normalizedFrameSelectionOrder(
                selection: normalizedSelection,
                frameIDsInDisplayOrder: workspace.frameIDsInDisplayOrder,
                preferredOrder: preferredOrder ?? state.selectedFrameSelectionOrderByCutID[cutID],
                primaryID: workspace.selectedFrameID
            )
        } else {
            state.selectedFrameIDsByCutID.removeValue(forKey: cutID)
            state.selectedFrameSelectionOrderByCutID.removeValue(forKey: cutID)
        }

        if let anchorID = workspace.selectedFrameSelectionAnchorID {
            state.frameSelectionAnchorByCutID[cutID] = anchorID
        } else {
            state.frameSelectionAnchorByCutID.removeValue(forKey: cutID)
        }
    }

    public static func resolveFrameSelectionOrder(
        for frameID: UUID,
        modifiers: WorkspaceSelectionModifiers,
        in workspace: ProjectFrameSelectionMemoryWorkspaceState,
        cutID: UUID,
        state: ProjectFrameSelectionMemoryState
    ) -> [UUID] {
        let frameIDsInDisplayOrder = workspace.frameIDsInDisplayOrder
        let currentSelection = normalizedFrameSelectionSet(
            workspace.selectedFrameIDs,
            primaryID: workspace.selectedFrameID
        )
        let currentOrder = normalizedFrameSelectionOrder(
            selection: currentSelection,
            frameIDsInDisplayOrder: frameIDsInDisplayOrder,
            preferredOrder: state.selectedFrameSelectionOrderByCutID[cutID],
            primaryID: workspace.selectedFrameID
        )

        if modifiers.contains(.range),
           let anchorID = workspace.selectedFrameSelectionAnchorID,
           let rangeIDs = contiguousFrameIDs(
               between: anchorID,
               and: frameID,
               in: frameIDsInDisplayOrder
           ) {
            return rangeIDs
        }

        if modifiers.contains(.additive) {
            if currentSelection.contains(frameID) {
                if currentSelection.count == 1 {
                    return [frameID]
                }
                return currentOrder.filter { $0 != frameID }
            }
            return currentOrder + [frameID]
        }

        return [frameID]
    }

    public static func normalizedFrameSelectionSet(
        _ selection: Set<UUID>,
        primaryID: UUID?
    ) -> Set<UUID> {
        var normalizedSelection = selection
        if let primaryID {
            normalizedSelection.insert(primaryID)
        }
        return normalizedSelection
    }

    public static func normalizedFrameSelectionOrder(
        selection: Set<UUID>,
        frameIDsInDisplayOrder: [UUID],
        preferredOrder: [UUID]?,
        primaryID: UUID?
    ) -> [UUID] {
        guard selection.isEmpty == false else { return [] }

        let validSelection = selection.intersection(Set(frameIDsInDisplayOrder))
        guard validSelection.isEmpty == false else { return [] }

        var orderedSelection: [UUID] = []
        var seenIDs: Set<UUID> = []
        for frameID in preferredOrder ?? [] {
            guard validSelection.contains(frameID), seenIDs.insert(frameID).inserted else {
                continue
            }
            orderedSelection.append(frameID)
        }
        for frameID in frameIDsInDisplayOrder where validSelection.contains(frameID) {
            guard seenIDs.insert(frameID).inserted else { continue }
            orderedSelection.append(frameID)
        }
        if let primaryID,
           validSelection.contains(primaryID),
           seenIDs.contains(primaryID) == false {
            orderedSelection.append(primaryID)
        }
        return orderedSelection
    }

    public static func contiguousFrameIDs(
        between startFrameID: UUID,
        and endFrameID: UUID,
        in orderedFrameIDs: [UUID]
    ) -> [UUID]? {
        guard let startIndex = orderedFrameIDs.firstIndex(of: startFrameID),
              let endIndex = orderedFrameIDs.firstIndex(of: endFrameID) else {
            return nil
        }

        let lowerBound = min(startIndex, endIndex)
        let upperBound = max(startIndex, endIndex)
        return Array(orderedFrameIDs[lowerBound ... upperBound])
    }

    public static func orderedFrameIDs(
        for cutID: UUID,
        in state: ProjectFrameSelectionMemoryState
    ) -> [UUID] {
        state.workspaces[cutID]?.frameIDsInDisplayOrder ?? []
    }

    public static func orderedFrameSelectionIDs(
        in selection: Set<UUID>,
        for cutID: UUID,
        in state: ProjectFrameSelectionMemoryState
    ) -> [UUID] {
        orderedFrameIDs(for: cutID, in: state).filter { selection.contains($0) }
    }
}
