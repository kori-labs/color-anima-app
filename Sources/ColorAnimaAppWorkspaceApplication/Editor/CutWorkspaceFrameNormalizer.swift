import Foundation

enum CutWorkspaceFrameNormalizer {
    static func defaultFrameName(for position: Int) -> String {
        "Frame \(String(format: "%03d", max(position, 1)))"
    }

    static func orderedFrames(
        _ frames: [CutWorkspaceFrameWorkflowFrame]
    ) -> [CutWorkspaceFrameWorkflowFrame] {
        frames.sorted {
            if $0.orderIndex == $1.orderIndex {
                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
            return $0.orderIndex < $1.orderIndex
        }
    }

    static func normalizeFrameState(in state: inout CutWorkspaceFrameWorkflowState) {
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
        CutWorkspaceFrameReferenceManager.normalizeReferenceFrameState(in: &state)
        setLastOpenedFrameID(state.lastOpenedFrameID, in: &state)
    }

    static func setLastOpenedFrameID(
        _ frameID: UUID?,
        in state: inout CutWorkspaceFrameWorkflowState
    ) {
        if CutWorkspaceFrameReferenceManager.containsFrame(frameID, in: state) {
            state.lastOpenedFrameID = frameID
        } else {
            state.lastOpenedFrameID = state.orderedFrames.first?.id
        }
    }

    static func defaultNamedFrameIDs(
        in orderedFrames: [CutWorkspaceFrameWorkflowFrame]
    ) -> Set<UUID> {
        Set(orderedFrames.enumerated().compactMap { offset, frame in
            let defaultName = defaultFrameName(for: offset + 1)
            let trimmedName = frame.name.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmedName == defaultName ? frame.id : nil
        })
    }

    static func normalizedFrames(
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
}
