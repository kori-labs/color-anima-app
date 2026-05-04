import Foundation

enum CutWorkspaceFrameReferenceManager {
    static func setReferenceFrame(
        _ frameID: UUID?,
        in state: inout CutWorkspaceFrameWorkflowState
    ) {
        if let frameID {
            addReferenceFrame(frameID, in: &state)
            setActiveReferenceFrame(frameID, in: &state)
        } else {
            state.keyFrameIDs = []
            state.activeReferenceFrameID = nil
        }
        state.isDirty = true
    }

    @discardableResult
    static func addReferenceFrame(
        _ frameID: UUID,
        in state: inout CutWorkspaceFrameWorkflowState
    ) -> Bool {
        guard containsFrame(frameID, in: state) else { return false }

        if state.keyFrameIDs.contains(frameID) {
            if state.activeReferenceFrameID == nil {
                state.activeReferenceFrameID = frameID
            }
            normalizeReferenceFrameState(in: &state)
            state.isDirty = true
            return true
        }

        guard state.orderedFrames.count <= 1 || state.keyFrameIDs.count < state.orderedFrames.count - 1 else {
            return false
        }

        state.keyFrameIDs.append(frameID)
        if state.activeReferenceFrameID == nil {
            state.activeReferenceFrameID = frameID
        }
        normalizeReferenceFrameState(in: &state)
        state.isDirty = true
        return true
    }

    static func removeReferenceFrame(
        _ frameID: UUID,
        in state: inout CutWorkspaceFrameWorkflowState
    ) {
        guard state.keyFrameIDs.contains(frameID) else { return }

        let remainingReferenceFrameIDs = state.keyFrameIDs.filter { $0 != frameID }
        if state.activeReferenceFrameID == frameID {
            state.activeReferenceFrameID = promotedReferenceFrameID(
                afterRemovingActiveReference: frameID,
                remainingReferenceFrameIDs: remainingReferenceFrameIDs,
                orderedFrameIDs: state.orderedFrameIDs
            )
        }
        state.keyFrameIDs = remainingReferenceFrameIDs
        normalizeReferenceFrameState(in: &state)
        state.isDirty = true
    }

    static func setActiveReferenceFrame(
        _ frameID: UUID?,
        in state: inout CutWorkspaceFrameWorkflowState
    ) {
        guard let frameID else {
            state.activeReferenceFrameID = nil
            normalizeReferenceFrameState(in: &state)
            state.isDirty = true
            return
        }

        state.activeReferenceFrameID = state.keyFrameIDs.contains(frameID) ? frameID : nil
        normalizeReferenceFrameState(in: &state)
        state.isDirty = true
    }

    static func normalizeReferenceFrameState(
        in state: inout CutWorkspaceFrameWorkflowState
    ) {
        let validReferenceFrameIDs = normalizedReferenceFrameIDs(state.keyFrameIDs, in: state)
        state.keyFrameIDs = validReferenceFrameIDs

        if let activeReferenceFrameID = state.activeReferenceFrameID,
           validReferenceFrameIDs.contains(activeReferenceFrameID) {
            state.activeReferenceFrameID = activeReferenceFrameID
        } else {
            state.activeReferenceFrameID = validReferenceFrameIDs.first
        }
    }

    private static func normalizedReferenceFrameIDs(
        _ candidateReferenceFrameIDs: [UUID],
        in state: CutWorkspaceFrameWorkflowState
    ) -> [UUID] {
        let validReferenceFrameIDSet = Set(candidateReferenceFrameIDs.filter { containsFrame($0, in: state) })
        return state.orderedFrameIDs.filter { validReferenceFrameIDSet.contains($0) }
    }

    static func promotedReferenceFrameID(
        afterRemovingActiveReference removedFrameID: UUID,
        remainingReferenceFrameIDs: [UUID],
        orderedFrameIDs: [UUID]
    ) -> UUID? {
        let remainingReferenceFrameIDSet = Set(remainingReferenceFrameIDs)
        guard remainingReferenceFrameIDSet.isEmpty == false else { return nil }

        if let removedIndex = orderedFrameIDs.firstIndex(of: removedFrameID),
           let nextReferenceFrameID = orderedFrameIDs
            .dropFirst(removedIndex + 1)
            .first(where: { remainingReferenceFrameIDSet.contains($0) }) {
            return nextReferenceFrameID
        }

        return orderedFrameIDs.first(where: { remainingReferenceFrameIDSet.contains($0) })
    }

    static func containsFrame(
        _ frameID: UUID?,
        in state: CutWorkspaceFrameWorkflowState
    ) -> Bool {
        guard let frameID else { return false }
        return state.frames.contains(where: { $0.id == frameID })
    }
}
