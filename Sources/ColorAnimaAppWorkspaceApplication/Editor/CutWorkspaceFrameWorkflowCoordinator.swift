import Foundation

public struct CutWorkspaceFrameWorkflowFrame: Identifiable, Hashable, Equatable, Sendable {
    public var id: UUID
    public var orderIndex: Int
    public var name: String
    public var assets: CutAssetCatalog

    public init(
        id: UUID = UUID(),
        orderIndex: Int = 0,
        name: String = CutWorkspaceFrameWorkflowCoordinator.defaultFrameName(for: 1),
        assets: CutAssetCatalog = CutAssetCatalog()
    ) {
        self.id = id
        self.orderIndex = orderIndex
        self.name = name
        self.assets = assets
    }
}

public struct CutWorkspaceFrameWorkflowState: Hashable, Equatable, Sendable {
    public var frames: [CutWorkspaceFrameWorkflowFrame]
    public var selectedFrameID: UUID?
    public var selectedFrameIDs: Set<UUID>
    public var selectedFrameSelectionAnchorID: UUID?
    public var lastOpenedFrameID: UUID?
    public var keyFrameIDs: [UUID]
    public var activeReferenceFrameID: UUID?
    public var isDirty: Bool
    public var isFramePlaybackActive: Bool
    public var documentRevision: Int
    public var removedFrameIDs: Set<UUID>
    public var needsFramePresentationPreparation: Bool
    public var framePresentationRestoreFrameID: UUID?
    public var framePresentationSeedFrameID: UUID?

    public init(
        frames: [CutWorkspaceFrameWorkflowFrame] = [],
        selectedFrameID: UUID? = nil,
        selectedFrameIDs: Set<UUID> = [],
        selectedFrameSelectionAnchorID: UUID? = nil,
        lastOpenedFrameID: UUID? = nil,
        keyFrameIDs: [UUID] = [],
        activeReferenceFrameID: UUID? = nil,
        isDirty: Bool = false,
        isFramePlaybackActive: Bool = false,
        documentRevision: Int = 0,
        removedFrameIDs: Set<UUID> = [],
        needsFramePresentationPreparation: Bool = false,
        framePresentationRestoreFrameID: UUID? = nil,
        framePresentationSeedFrameID: UUID? = nil
    ) {
        self.frames = frames
        self.selectedFrameID = selectedFrameID
        self.selectedFrameIDs = selectedFrameIDs
        self.selectedFrameSelectionAnchorID = selectedFrameSelectionAnchorID
        self.lastOpenedFrameID = lastOpenedFrameID
        self.keyFrameIDs = keyFrameIDs
        self.activeReferenceFrameID = activeReferenceFrameID
        self.isDirty = isDirty
        self.isFramePlaybackActive = isFramePlaybackActive
        self.documentRevision = documentRevision
        self.removedFrameIDs = removedFrameIDs
        self.needsFramePresentationPreparation = needsFramePresentationPreparation
        self.framePresentationRestoreFrameID = framePresentationRestoreFrameID
        self.framePresentationSeedFrameID = framePresentationSeedFrameID
        CutWorkspaceFrameWorkflowCoordinator.normalizeFrameState(in: &self)
    }

    public var orderedFrames: [CutWorkspaceFrameWorkflowFrame] {
        CutWorkspaceFrameWorkflowCoordinator.orderedFrames(frames)
    }

    public var orderedFrameIDs: [UUID] {
        orderedFrames.map(\.id)
    }
}

public enum CutWorkspaceFrameWorkflowCoordinator {
    public static func defaultFrameName(for position: Int) -> String {
        "Frame \(String(format: "%03d", max(position, 1)))"
    }

    public static func orderedFrames(
        _ frames: [CutWorkspaceFrameWorkflowFrame]
    ) -> [CutWorkspaceFrameWorkflowFrame] {
        frames.sorted {
            if $0.orderIndex == $1.orderIndex {
                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
            return $0.orderIndex < $1.orderIndex
        }
    }

    @discardableResult
    public static func createFrame(
        named name: String? = nil,
        id: UUID = UUID(),
        in state: inout CutWorkspaceFrameWorkflowState
    ) -> CutWorkspaceFrameWorkflowFrame {
        prepareForFramePresentationTransition(in: &state)

        let nextPosition = state.orderedFrames.count + 1
        let frame = CutWorkspaceFrameWorkflowFrame(
            id: id,
            orderIndex: state.orderedFrames.count,
            name: name ?? defaultFrameName(for: nextPosition)
        )
        state.frames.append(frame)
        activateNewFrame(id, in: &state)
        markDocumentChanged(in: &state)
        return frame
    }

    @discardableResult
    public static func moveFrames(
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

        let defaultNameFrameIDs = defaultNamedFrameIDs(in: currentFrames)
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

        state.frames = normalizedFrames(reorderedFrames, defaultNameFrameIDs: defaultNameFrameIDs)
        normalizeReferenceFrameState(in: &state)
        setLastOpenedFrameID(state.lastOpenedFrameID, in: &state)

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
    public static func deleteFrames(
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

        let defaultNameFrameIDs = defaultNamedFrameIDs(in: currentFrames)
        let remainingFrames = currentFrames.filter { deletingFrameIDSet.contains($0.id) == false }
        state.frames = normalizedFrames(remainingFrames, defaultNameFrameIDs: defaultNameFrameIDs)
        state.removedFrameIDs.formUnion(deletingFrameIDSet)
        state.keyFrameIDs = state.keyFrameIDs.filter { deletingFrameIDSet.contains($0) == false }
        if let activeReferenceFrameID = state.activeReferenceFrameID,
           deletingFrameIDSet.contains(activeReferenceFrameID) {
            state.activeReferenceFrameID = promotedReferenceFrameID(
                afterRemovingActiveReference: activeReferenceFrameID,
                remainingReferenceFrameIDs: state.keyFrameIDs,
                orderedFrameIDs: currentFrames.map(\.id)
            )
        }
        normalizeReferenceFrameState(in: &state)

        state.selectedFrameID = primaryFrameID
        state.selectedFrameIDs = [primaryFrameID]
        state.selectedFrameSelectionAnchorID = primaryFrameID
        state.lastOpenedFrameID = primaryFrameID
        state.isFramePlaybackActive = false
        state.framePresentationRestoreFrameID = primaryFrameID
        markDocumentChanged(in: &state)
        return primaryFrameID
    }

    public static func setReferenceFrame(
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
    public static func addReferenceFrame(
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

    public static func removeReferenceFrame(
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

    public static func setActiveReferenceFrame(
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

    public static func setLastOpenedFrameID(
        _ frameID: UUID?,
        in state: inout CutWorkspaceFrameWorkflowState
    ) {
        if containsFrame(frameID, in: state) {
            state.lastOpenedFrameID = frameID
        } else {
            state.lastOpenedFrameID = state.orderedFrames.first?.id
        }
    }

    public static func normalizeFrameState(in state: inout CutWorkspaceFrameWorkflowState) {
        if state.frames.isEmpty {
            state.frames = [
                CutWorkspaceFrameWorkflowFrame(
                    orderIndex: 0,
                    name: defaultFrameName(for: 1)
                )
            ]
        }

        state.frames = state.orderedFrames.enumerated().map { offset, frame in
            var copy = frame
            copy.orderIndex = offset
            if copy.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                copy.name = defaultFrameName(for: offset + 1)
            }
            return copy
        }
        normalizeReferenceFrameState(in: &state)
        setLastOpenedFrameID(state.lastOpenedFrameID, in: &state)
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

    private static func containsFrame(
        _ frameID: UUID?,
        in state: CutWorkspaceFrameWorkflowState
    ) -> Bool {
        guard let frameID else { return false }
        return state.frames.contains(where: { $0.id == frameID })
    }

    private static func uniqueIDs(_ frameIDs: [UUID]) -> [UUID] {
        frameIDs.reduce(into: [UUID]()) { result, frameID in
            if result.contains(frameID) == false {
                result.append(frameID)
            }
        }
    }

    private static func defaultNamedFrameIDs(
        in orderedFrames: [CutWorkspaceFrameWorkflowFrame]
    ) -> Set<UUID> {
        Set(orderedFrames.enumerated().compactMap { offset, frame in
            let defaultName = defaultFrameName(for: offset + 1)
            let trimmedName = frame.name.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmedName == defaultName ? frame.id : nil
        })
    }

    private static func normalizedFrames(
        _ orderedFrames: [CutWorkspaceFrameWorkflowFrame],
        defaultNameFrameIDs: Set<UUID>
    ) -> [CutWorkspaceFrameWorkflowFrame] {
        orderedFrames.enumerated().map { offset, frame in
            var copy = frame
            copy.orderIndex = offset
            if defaultNameFrameIDs.contains(copy.id) {
                copy.name = defaultFrameName(for: offset + 1)
            }
            return copy
        }
    }

    private static func normalizeReferenceFrameState(
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

    private static func promotedReferenceFrameID(
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
}
