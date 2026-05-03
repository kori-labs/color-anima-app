import Foundation

public enum CutWorkspaceCutGapReviewCoordinator {
    public static func currentSelection(
        activeFrameID: UUID?,
        sessionsByFrameID: [UUID: CutWorkspaceGapReviewFrameSession]
    ) -> CutGapReviewCursor? {
        guard let activeFrameID,
              let session = sessionsByFrameID[activeFrameID],
              let candidateID = session.selectedCandidateID else {
            return nil
        }
        return CutGapReviewCursor(frameID: activeFrameID, candidateID: candidateID)
    }

    @discardableResult
    public static func advanceToNextPending(
        frameOrder: [UUID],
        sessionsByFrameID: inout [UUID: CutWorkspaceGapReviewFrameSession],
        activeFrameID: inout UUID?
    ) -> CutGapReviewCursor? {
        let entries = flattenedEntries(frameOrder: frameOrder, sessionsByFrameID: sessionsByFrameID)
        guard entries.isEmpty == false else {
            clearActiveSelection(activeFrameID: activeFrameID, sessionsByFrameID: &sessionsByFrameID)
            return nil
        }

        let pivotIndex = currentPivotIndex(
            activeFrameID: activeFrameID,
            sessionsByFrameID: sessionsByFrameID,
            entries: entries
        )
        let count = entries.count
        for offset in 1...count {
            let index = ((pivotIndex + offset) % count + count) % count
            let entry = entries[index]
            if entry.isPending {
                applyCursor(
                    frameID: entry.frameID,
                    candidateID: entry.candidateID,
                    sessionsByFrameID: &sessionsByFrameID,
                    activeFrameID: &activeFrameID
                )
                return CutGapReviewCursor(frameID: entry.frameID, candidateID: entry.candidateID)
            }
        }

        clearActiveSelection(activeFrameID: activeFrameID, sessionsByFrameID: &sessionsByFrameID)
        return nil
    }

    private struct Entry {
        let frameID: UUID
        let candidateID: UUID
        let isPending: Bool
    }

    private static func flattenedEntries(
        frameOrder: [UUID],
        sessionsByFrameID: [UUID: CutWorkspaceGapReviewFrameSession]
    ) -> [Entry] {
        var entries: [Entry] = []
        for frameID in frameOrder {
            guard let session = sessionsByFrameID[frameID] else { continue }
            for candidate in session.candidates {
                entries.append(Entry(
                    frameID: frameID,
                    candidateID: candidate.id,
                    isPending: candidate.reviewState == .pending
                ))
            }
        }
        return entries
    }

    private static func currentPivotIndex(
        activeFrameID: UUID?,
        sessionsByFrameID: [UUID: CutWorkspaceGapReviewFrameSession],
        entries: [Entry]
    ) -> Int {
        guard let activeFrameID,
              let activeSession = sessionsByFrameID[activeFrameID],
              let activeCandidateID = activeSession.selectedCandidateID else {
            return -1
        }
        return entries.firstIndex {
            $0.frameID == activeFrameID && $0.candidateID == activeCandidateID
        } ?? -1
    }

    private static func applyCursor(
        frameID: UUID,
        candidateID: UUID,
        sessionsByFrameID: inout [UUID: CutWorkspaceGapReviewFrameSession],
        activeFrameID: inout UUID?
    ) {
        if let priorFrameID = activeFrameID,
           priorFrameID != frameID,
           var priorSession = sessionsByFrameID[priorFrameID] {
            priorSession.selectedCandidateID = nil
            sessionsByFrameID[priorFrameID] = priorSession
        }

        if var session = sessionsByFrameID[frameID] {
            session.selectedCandidateID = candidateID
            sessionsByFrameID[frameID] = session
        }
        activeFrameID = frameID
    }

    private static func clearActiveSelection(
        activeFrameID: UUID?,
        sessionsByFrameID: inout [UUID: CutWorkspaceGapReviewFrameSession]
    ) {
        guard let activeFrameID,
              var session = sessionsByFrameID[activeFrameID] else {
            return
        }
        session.selectedCandidateID = nil
        sessionsByFrameID[activeFrameID] = session
    }
}
