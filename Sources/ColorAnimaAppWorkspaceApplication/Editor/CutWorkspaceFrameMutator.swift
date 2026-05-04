import Foundation

enum CutWorkspaceFrameMutator {
    @discardableResult
    static func createFrame(
        named name: String? = nil,
        id: UUID = UUID(),
        in state: inout CutWorkspaceFrameWorkflowState
    ) -> CutWorkspaceFrameWorkflowFrame {
        prepareForFramePresentationTransition(in: &state)

        let nextPosition = state.orderedFrames.count + 1
        let frame = CutWorkspaceFrameWorkflowFrame(
            id: id,
            orderIndex: state.orderedFrames.count,
            name: name ?? CutWorkspaceFrameNormalizer.defaultFrameName(for: nextPosition)
        )
        state.frames.append(frame)
        activateNewFrame(id, in: &state)
        markDocumentChanged(in: &state)
        return frame
    }

    @discardableResult
    static func moveFrames(
        _ frameIDs: [UUID],
        to target: WorkspaceFrameDropTarget,
        in state: inout CutWorkspaceFrameWorkflowState
    ) -> [UUID]? {
        prepareForFramePresentationTransition(in: &state)

        let uniqueFrameIDs = uniqueIDs(frameIDs)
        let currentFrames = state.orderedFrames
        let movingFrames = currentFrames.filter { uniqueFrameIDs.contains($0.id) }
        guard movingFrames.isEmpty == false else { return nil }

        let movingFrameIDSet = Set(movingFrames.map(\.id))
        if let targetFrameID = target.targetFrameID,
           movingFrameIDSet.contains(targetFrameID) {
            return nil
        }

        let defaultNameFrameIDs = CutWorkspaceFrameNormalizer.defaultNamedFrameIDs(in: currentFrames)
        let remainingFrames = currentFrames.filter { movingFrameIDSet.contains($0.id) == false }
        let insertionIndex: Int
        switch target.position {
        case .before:
            guard let targetFrameID = target.targetFrameID,
                  let targetIndex = remainingFrames.firstIndex(where: { $0.id == targetFrameID }) else {
                return nil
            }
            insertionIndex = targetIndex
        case .after:
            guard let targetFrameID = target.targetFrameID,
                  let targetIndex = remainingFrames.firstIndex(where: { $0.id == targetFrameID }) else {
                return nil
            }
            insertionIndex = targetIndex + 1
        case .append:
            insertionIndex = remainingFrames.count
        }

        let reorderedFrames = Array(remainingFrames.prefix(insertionIndex))
            + movingFrames
            + Array(remainingFrames.suffix(from: insertionIndex))
        guard reorderedFrames.map(\.id) != currentFrames.map(\.id) else { return nil }

        state.frames = CutWorkspaceFrameNormalizer.normalizedFrames(reorderedFrames, defaultNameFrameIDs: defaultNameFrameIDs)
        CutWorkspaceFrameReferenceManager.normalizeReferenceFrameState(in: &state)
        CutWorkspaceFrameNormalizer.setLastOpenedFrameID(state.lastOpenedFrameID, in: &state)

        let movedFrameIDs = reorderedFrames.map(\.id).filter { movingFrameIDSet.contains($0) }
        if let nextPrimaryFrameID = movedFrameIDs.first {
            state.selectedFrameID = nextPrimaryFrameID
            state.selectedFrameIDs = Set(movedFrameIDs)
            state.selectedFrameSelectionAnchorID = nextPrimaryFrameID
            state.lastOpenedFrameID = nextPrimaryFrameID
            state.framePresentationRestoreFrameID = nextPrimaryFrameID
        }
        markDocumentChanged(in: &state)
        return movedFrameIDs
    }

    @discardableResult
    static func deleteFrames(
        _ frameIDs: [UUID],
        in state: inout CutWorkspaceFrameWorkflowState
    ) -> UUID? {
        prepareForFramePresentationTransition(in: &state)

        let uniqueFrameIDs = uniqueIDs(frameIDs)
        let currentFrames = state.orderedFrames
        let deletingFrames = currentFrames.filter { uniqueFrameIDs.contains($0.id) }
        let deletingFrameIDSet = Set(deletingFrames.map(\.id))
        guard deletingFrameIDSet.isEmpty == false,
              deletingFrameIDSet.count < currentFrames.count else {
            return nil
        }

        let deletingIndices = currentFrames.enumerated().compactMap { index, frame in
            deletingFrameIDSet.contains(frame.id) ? index : nil
        }
        guard let lowestDeletedIndex = deletingIndices.min(),
              let highestDeletedIndex = deletingIndices.max() else {
            return nil
        }

        let rightNeighbor = currentFrames.enumerated().first { index, frame in
            index > highestDeletedIndex && deletingFrameIDSet.contains(frame.id) == false
        }?.element
        let leftNeighbor = currentFrames[..<lowestDeletedIndex].last { frame in
            deletingFrameIDSet.contains(frame.id) == false
        }
        guard let primaryFrameID = rightNeighbor?.id ?? leftNeighbor?.id else {
            return nil
        }

        let defaultNameFrameIDs = CutWorkspaceFrameNormalizer.defaultNamedFrameIDs(in: currentFrames)
        let remainingFrames = currentFrames.filter { deletingFrameIDSet.contains($0.id) == false }
        state.frames = CutWorkspaceFrameNormalizer.normalizedFrames(remainingFrames, defaultNameFrameIDs: defaultNameFrameIDs)
        state.removedFrameIDs.formUnion(deletingFrameIDSet)
        state.keyFrameIDs = state.keyFrameIDs.filter { deletingFrameIDSet.contains($0) == false }
        if let activeReferenceFrameID = state.activeReferenceFrameID,
           deletingFrameIDSet.contains(activeReferenceFrameID) {
            state.activeReferenceFrameID = CutWorkspaceFrameReferenceManager.promotedReferenceFrameID(
                afterRemovingActiveReference: activeReferenceFrameID,
                remainingReferenceFrameIDs: state.keyFrameIDs,
                orderedFrameIDs: currentFrames.map(\.id)
            )
        }
        CutWorkspaceFrameReferenceManager.normalizeReferenceFrameState(in: &state)

        state.selectedFrameID = primaryFrameID
        state.selectedFrameIDs = [primaryFrameID]
        state.selectedFrameSelectionAnchorID = primaryFrameID
        state.lastOpenedFrameID = primaryFrameID
        state.isFramePlaybackActive = false
        state.framePresentationRestoreFrameID = primaryFrameID
        markDocumentChanged(in: &state)
        return primaryFrameID
    }

    private static func activateNewFrame(
        _ frameID: UUID,
        in state: inout CutWorkspaceFrameWorkflowState
    ) {
        state.framePresentationSeedFrameID = frameID
        state.selectedFrameID = frameID
        state.selectedFrameIDs = [frameID]
        state.selectedFrameSelectionAnchorID = frameID
        state.lastOpenedFrameID = frameID
        state.framePresentationRestoreFrameID = frameID
    }

    private static func prepareForFramePresentationTransition(
        in state: inout CutWorkspaceFrameWorkflowState
    ) {
        state.needsFramePresentationPreparation = true
    }

    private static func markDocumentChanged(in state: inout CutWorkspaceFrameWorkflowState) {
        state.isDirty = true
        state.documentRevision += 1
    }

    private static func uniqueIDs(_ frameIDs: [UUID]) -> [UUID] {
        frameIDs.reduce(into: [UUID]()) { result, frameID in
            if result.contains(frameID) == false {
                result.append(frameID)
            }
        }
    }
}
