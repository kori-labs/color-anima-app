import XCTest
@testable import ColorAnimaAppWorkspaceApplication

final class CutWorkspaceCutGapReviewCoordinatorTests: XCTestCase {
    func testCurrentSelectionIsNilWhenNoActiveFrame() {
        let frameID = UUID()
        let candidate = makeCandidate()
        let sessions = [
            frameID: CutWorkspaceGapReviewFrameSession(
                frameID: frameID,
                candidates: [candidate],
                selectedCandidateID: candidate.id
            )
        ]

        XCTAssertNil(
            CutWorkspaceCutGapReviewCoordinator.currentSelection(
                activeFrameID: nil,
                sessionsByFrameID: sessions
            )
        )
    }

    func testAdvanceFromEmptyCursorLandsOnFirstPendingOfFirstFrame() {
        let frameA = UUID()
        let frameB = UUID()
        let candidateA1 = makeCandidate()
        let candidateB1 = makeCandidate()
        var sessions = [
            frameA: CutWorkspaceGapReviewFrameSession(frameID: frameA, candidates: [candidateA1]),
            frameB: CutWorkspaceGapReviewFrameSession(frameID: frameB, candidates: [candidateB1]),
        ]
        var activeFrameID: UUID?

        let cursor = CutWorkspaceCutGapReviewCoordinator.advanceToNextPending(
            frameOrder: [frameA, frameB],
            sessionsByFrameID: &sessions,
            activeFrameID: &activeFrameID
        )

        XCTAssertEqual(cursor, CutGapReviewCursor(frameID: frameA, candidateID: candidateA1.id))
        XCTAssertEqual(activeFrameID, frameA)
        XCTAssertEqual(sessions[frameA]?.selectedCandidateID, candidateA1.id)
    }

    func testAdvanceCrossesFrameBoundaryWhenCurrentFrameExhausted() {
        let frameA = UUID()
        let frameB = UUID()
        let resolvedA = makeCandidate(reviewState: .acceptedSuggested)
        let candidateB1 = makeCandidate()
        var sessions = [
            frameA: CutWorkspaceGapReviewFrameSession(
                frameID: frameA,
                candidates: [resolvedA],
                selectedCandidateID: resolvedA.id
            ),
            frameB: CutWorkspaceGapReviewFrameSession(frameID: frameB, candidates: [candidateB1]),
        ]
        var activeFrameID: UUID? = frameA

        let cursor = CutWorkspaceCutGapReviewCoordinator.advanceToNextPending(
            frameOrder: [frameA, frameB],
            sessionsByFrameID: &sessions,
            activeFrameID: &activeFrameID
        )

        XCTAssertEqual(cursor, CutGapReviewCursor(frameID: frameB, candidateID: candidateB1.id))
        XCTAssertEqual(activeFrameID, frameB)
        XCTAssertNil(sessions[frameA]?.selectedCandidateID)
    }

    func testAdvanceWrapsAroundTheCutOnceWhenLastFrameSelected() {
        let frameA = UUID()
        let frameB = UUID()
        let candidateA1 = makeCandidate()
        let candidateB1 = makeCandidate()
        var sessions = [
            frameA: CutWorkspaceGapReviewFrameSession(frameID: frameA, candidates: [candidateA1]),
            frameB: CutWorkspaceGapReviewFrameSession(
                frameID: frameB,
                candidates: [candidateB1],
                selectedCandidateID: candidateB1.id
            ),
        ]
        var activeFrameID: UUID? = frameB

        let cursor = CutWorkspaceCutGapReviewCoordinator.advanceToNextPending(
            frameOrder: [frameA, frameB],
            sessionsByFrameID: &sessions,
            activeFrameID: &activeFrameID
        )

        XCTAssertEqual(cursor, CutGapReviewCursor(frameID: frameA, candidateID: candidateA1.id))
        XCTAssertEqual(activeFrameID, frameA)
    }

    func testAdvanceReturnsNilAndClearsSelectionWhenAllResolved() {
        let frameA = UUID()
        let frameB = UUID()
        let resolvedA = makeCandidate(reviewState: .acceptedSuggested)
        let resolvedB = makeCandidate(reviewState: .ignored)
        var sessions = [
            frameA: CutWorkspaceGapReviewFrameSession(
                frameID: frameA,
                candidates: [resolvedA],
                selectedCandidateID: resolvedA.id
            ),
            frameB: CutWorkspaceGapReviewFrameSession(frameID: frameB, candidates: [resolvedB]),
        ]
        var activeFrameID: UUID? = frameA

        let cursor = CutWorkspaceCutGapReviewCoordinator.advanceToNextPending(
            frameOrder: [frameA, frameB],
            sessionsByFrameID: &sessions,
            activeFrameID: &activeFrameID
        )

        XCTAssertNil(cursor)
        XCTAssertNil(sessions[frameA]?.selectedCandidateID)
    }

    func testAdvanceReturnsNilWhenNoSessionsExist() {
        let frameID = UUID()
        var sessions: [UUID: CutWorkspaceGapReviewFrameSession] = [:]
        var activeFrameID: UUID?

        let cursor = CutWorkspaceCutGapReviewCoordinator.advanceToNextPending(
            frameOrder: [frameID],
            sessionsByFrameID: &sessions,
            activeFrameID: &activeFrameID
        )

        XCTAssertNil(cursor)
        XCTAssertNil(activeFrameID)
    }

    func testCurrentSelectionFollowsAdvance() {
        let frameID = UUID()
        let candidate = makeCandidate()
        var sessions = [
            frameID: CutWorkspaceGapReviewFrameSession(frameID: frameID, candidates: [candidate])
        ]
        var activeFrameID: UUID?

        _ = CutWorkspaceCutGapReviewCoordinator.advanceToNextPending(
            frameOrder: [frameID],
            sessionsByFrameID: &sessions,
            activeFrameID: &activeFrameID
        )

        XCTAssertEqual(
            CutWorkspaceCutGapReviewCoordinator.currentSelection(
                activeFrameID: activeFrameID,
                sessionsByFrameID: sessions
            ),
            CutGapReviewCursor(frameID: frameID, candidateID: candidate.id)
        )
    }

    private func makeCandidate(
        id: UUID = UUID(),
        reviewState: GapReviewCandidateState = .pending
    ) -> GapReviewCandidatePresentation {
        GapReviewCandidatePresentation(
            id: id,
            area: 4,
            pixelCount: 4,
            confidence: 0.8,
            suggestedColor: RGBAColor(red: 0.5, green: 0.5, blue: 0.5),
            reviewState: reviewState
        )
    }
}
