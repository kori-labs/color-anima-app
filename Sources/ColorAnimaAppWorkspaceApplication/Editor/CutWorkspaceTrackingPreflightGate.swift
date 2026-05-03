import Foundation

public struct CutGapReviewCursor: Hashable, Sendable {
    public let frameID: UUID
    public let candidateID: UUID

    public init(frameID: UUID, candidateID: UUID) {
        self.frameID = frameID
        self.candidateID = candidateID
    }
}

public struct CutWorkspaceGapReviewFrameSession: Hashable, Sendable {
    public let frameID: UUID
    public var candidates: [GapReviewCandidatePresentation]
    public var selectedCandidateID: UUID?

    public init(
        frameID: UUID,
        candidates: [GapReviewCandidatePresentation],
        selectedCandidateID: UUID? = nil
    ) {
        self.frameID = frameID
        self.candidates = candidates
        if let selectedCandidateID,
           candidates.contains(where: { $0.id == selectedCandidateID }) {
            self.selectedCandidateID = selectedCandidateID
        } else {
            self.selectedCandidateID = nil
        }
    }

    public mutating func clearSelection() {
        selectedCandidateID = nil
    }
}

public struct CutWorkspaceGapReviewRoute: Equatable, Sendable {
    public let sessionsByFrameID: [UUID: CutWorkspaceGapReviewFrameSession]
    public let activeFrameID: UUID?
    public let cursor: CutGapReviewCursor?

    public init(
        sessionsByFrameID: [UUID: CutWorkspaceGapReviewFrameSession],
        activeFrameID: UUID?,
        cursor: CutGapReviewCursor?
    ) {
        self.sessionsByFrameID = sessionsByFrameID
        self.activeFrameID = activeFrameID
        self.cursor = cursor
    }
}

public enum CutWorkspaceTrackingPreflightGate {
    public enum Outcome: Equatable, Sendable {
        case proceed
        case requiresReview(
            summary: CutWorkspaceTrackingPreflightSummary,
            firstUnresolved: CutGapReviewCursor?
        )
    }

    public static func evaluate(
        frameOrder: [UUID],
        sessionsByFrameID: [UUID: CutWorkspaceGapReviewFrameSession]
    ) -> Outcome {
        guard let summary = CutWorkspaceTrackingPreflightSummary.aggregate(
            sessions: sessionsByFrameID.values
        ) else {
            return .proceed
        }
        guard summary.hasUnresolvedReviewState else {
            return .proceed
        }
        return .requiresReview(
            summary: summary,
            firstUnresolved: firstUnresolvedCursor(
                frameOrder: frameOrder,
                sessionsByFrameID: sessionsByFrameID
            )
        )
    }

    public static func routeToReview(
        frameOrder: [UUID],
        sessionsByFrameID: [UUID: CutWorkspaceGapReviewFrameSession]
    ) -> CutWorkspaceGapReviewRoute {
        let clearedSessions = sessionsByFrameID.mapValues { session in
            var cleared = session
            cleared.clearSelection()
            return cleared
        }
        let cursor = firstUnresolvedCursor(
            frameOrder: frameOrder,
            sessionsByFrameID: clearedSessions
        )
        return CutWorkspaceGapReviewRoute(
            sessionsByFrameID: clearedSessions,
            activeFrameID: cursor?.frameID,
            cursor: cursor
        )
    }

    public static func firstUnresolvedCursor(
        frameOrder: [UUID],
        sessionsByFrameID: [UUID: CutWorkspaceGapReviewFrameSession]
    ) -> CutGapReviewCursor? {
        for frameID in frameOrder {
            guard let session = sessionsByFrameID[frameID] else { continue }
            if let candidate = session.candidates.first(where: { $0.reviewState == .pending }) {
                return CutGapReviewCursor(frameID: frameID, candidateID: candidate.id)
            }
        }
        return nil
    }
}
