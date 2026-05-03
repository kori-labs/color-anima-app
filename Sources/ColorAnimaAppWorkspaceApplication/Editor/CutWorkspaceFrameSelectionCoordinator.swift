import Foundation

public struct CutWorkspaceFrameSelectionFrame: Identifiable, Hashable, Equatable, Sendable {
    public var id: UUID

    public init(id: UUID = UUID()) {
        self.id = id
    }
}

public struct CutWorkspaceFrameSelectionState: Hashable, Equatable, Sendable {
    public var frames: [CutWorkspaceFrameSelectionFrame]
    public var selectedFrameID: UUID?
    public var selectedFrameIDs: Set<UUID>
    public var selectedFrameSelectionAnchorID: UUID?
    public var lastOpenedFrameID: UUID?

    public init(
        frames: [CutWorkspaceFrameSelectionFrame] = [],
        selectedFrameID: UUID? = nil,
        selectedFrameIDs: Set<UUID> = [],
        selectedFrameSelectionAnchorID: UUID? = nil,
        lastOpenedFrameID: UUID? = nil
    ) {
        self.frames = frames
        self.selectedFrameID = selectedFrameID
        self.selectedFrameIDs = selectedFrameIDs
        self.selectedFrameSelectionAnchorID = selectedFrameSelectionAnchorID
        self.lastOpenedFrameID = lastOpenedFrameID
    }

    public var orderedFrameIDs: [UUID] {
        frames.map(\.id)
    }

    public var resolvedSelectedFrameID: UUID? {
        let availableFrameIDs = Set(orderedFrameIDs)
        if let selectedFrameID, availableFrameIDs.contains(selectedFrameID) {
            return selectedFrameID
        }
        if let lastOpenedFrameID, availableFrameIDs.contains(lastOpenedFrameID) {
            return lastOpenedFrameID
        }
        return frames.first?.id
    }
}

public enum CutWorkspaceFrameSelectionOutcome: Hashable, Equatable, Sendable {
    case unchanged
    case changed(primaryFrameID: UUID, previousPrimaryFrameID: UUID?)
    case rejected
}

public enum CutWorkspaceFrameSelectionCoordinator {
    @discardableResult
    public static func selectFrame(
        _ frameID: UUID?,
        modifiers: WorkspaceSelectionModifiers = [],
        in state: inout CutWorkspaceFrameSelectionState
    ) -> CutWorkspaceFrameSelectionOutcome {
        guard let frameID else { return .rejected }
        let availableFrameIDs = Set(state.orderedFrameIDs)
        guard availableFrameIDs.contains(frameID) else { return .rejected }

        let currentPrimaryFrameID = state.resolvedSelectedFrameID
        let nextSelection = resolveFrameSelection(
            for: frameID,
            modifiers: modifiers,
            in: state
        )

        state.selectedFrameID = nextSelection.primaryID
        state.selectedFrameIDs = nextSelection.selection
        state.selectedFrameSelectionAnchorID = nextSelection.anchorID
        state.lastOpenedFrameID = nextSelection.primaryID

        guard nextSelection.primaryID != currentPrimaryFrameID else {
            return .unchanged
        }

        return .changed(
            primaryFrameID: nextSelection.primaryID,
            previousPrimaryFrameID: currentPrimaryFrameID
        )
    }

    public static func collapseSelectionToPrimaryFrame(
        in state: inout CutWorkspaceFrameSelectionState
    ) {
        guard let primaryFrameID = state.resolvedSelectedFrameID else { return }
        state.selectedFrameID = primaryFrameID
        state.selectedFrameIDs = [primaryFrameID]
        state.selectedFrameSelectionAnchorID = primaryFrameID
        state.lastOpenedFrameID = primaryFrameID
    }

    @discardableResult
    public static func selectPreviousFrame(
        in state: inout CutWorkspaceFrameSelectionState
    ) -> CutWorkspaceFrameSelectionOutcome? {
        selectAdjacentFrame(offset: -1, wrap: false, in: &state)
    }

    @discardableResult
    public static func selectNextFrame(
        in state: inout CutWorkspaceFrameSelectionState
    ) -> CutWorkspaceFrameSelectionOutcome? {
        selectAdjacentFrame(offset: 1, wrap: false, in: &state)
    }

    @discardableResult
    public static func advancePlaybackFrame(
        in state: inout CutWorkspaceFrameSelectionState
    ) -> CutWorkspaceFrameSelectionOutcome? {
        selectAdjacentFrame(offset: 1, wrap: true, in: &state)
    }

    private static func resolveFrameSelection(
        for frameID: UUID,
        modifiers: WorkspaceSelectionModifiers,
        in state: CutWorkspaceFrameSelectionState
    ) -> (selection: Set<UUID>, primaryID: UUID, anchorID: UUID?) {
        let orderedFrameIDs = state.orderedFrameIDs
        let availableFrameIDs = Set(orderedFrameIDs)
        let currentSelection = state.selectedFrameIDs.intersection(availableFrameIDs)
        let currentPrimaryID = state.resolvedSelectedFrameID ?? orderedFrameIDs.first ?? frameID
        let currentAnchorID = state.selectedFrameSelectionAnchorID.flatMap {
            availableFrameIDs.contains($0) ? $0 : nil
        }

        if modifiers.contains(.range),
           let anchorID = currentAnchorID,
           let rangeIDs = contiguousFrameIDs(between: anchorID, and: frameID, in: orderedFrameIDs) {
            return (Set(rangeIDs), frameID, anchorID)
        }

        if modifiers.contains(.additive) {
            var nextSelection = currentSelection
            if nextSelection.contains(frameID) {
                if nextSelection.count == 1 {
                    return ([frameID], frameID, frameID)
                }
                nextSelection.remove(frameID)
                if frameID == currentPrimaryID {
                    let nextPrimaryID = orderedFrameIDs.first(where: { nextSelection.contains($0) }) ?? frameID
                    return (nextSelection, nextPrimaryID, nextPrimaryID)
                }
                return (nextSelection, currentPrimaryID, currentPrimaryID)
            }

            nextSelection.insert(frameID)
            return (nextSelection, frameID, frameID)
        }

        return ([frameID], frameID, frameID)
    }

    private static func selectAdjacentFrame(
        offset: Int,
        wrap: Bool,
        in state: inout CutWorkspaceFrameSelectionState
    ) -> CutWorkspaceFrameSelectionOutcome? {
        let orderedFrameIDs = state.orderedFrameIDs
        guard let currentFrameID = state.resolvedSelectedFrameID,
              let currentIndex = orderedFrameIDs.firstIndex(of: currentFrameID),
              orderedFrameIDs.isEmpty == false
        else {
            return nil
        }

        let nextIndex: Int
        if wrap {
            let frameCount = orderedFrameIDs.count
            nextIndex = ((currentIndex + offset) % frameCount + frameCount) % frameCount
        } else {
            let candidateIndex = currentIndex + offset
            guard orderedFrameIDs.indices.contains(candidateIndex) else { return nil }
            nextIndex = candidateIndex
        }

        let nextFrameID = orderedFrameIDs[nextIndex]
        state.selectedFrameID = nextFrameID
        state.selectedFrameIDs = [nextFrameID]
        state.selectedFrameSelectionAnchorID = nextFrameID
        state.lastOpenedFrameID = nextFrameID

        guard nextFrameID != currentFrameID else {
            return .unchanged
        }

        return .changed(primaryFrameID: nextFrameID, previousPrimaryFrameID: currentFrameID)
    }

    private static func contiguousFrameIDs(
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
}
