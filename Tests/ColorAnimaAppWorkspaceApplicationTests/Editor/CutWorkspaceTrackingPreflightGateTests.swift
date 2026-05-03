import ColorAnimaAppWorkspaceApplication
import XCTest

final class CutWorkspaceTrackingPreflightGateTests: XCTestCase {
    func testEvaluateProceedsWhenNoGapReviewSessionsExist() {
        let frameID = UUID()

        let outcome = CutWorkspaceTrackingPreflightGate.evaluate(
            frameOrder: [frameID],
            sessionsByFrameID: [:]
        )

        XCTAssertEqual(outcome, .proceed)
    }

    func testEvaluateProceedsWhenSessionsExistButAllResolved() {
        let frameID = UUID()
        let resolved = makeCandidate(reviewState: .acceptedSuggested)
        let sessions = [
            frameID: CutWorkspaceGapReviewFrameSession(
                frameID: frameID,
                candidates: [resolved]
            ),
        ]

        let outcome = CutWorkspaceTrackingPreflightGate.evaluate(
            frameOrder: [frameID],
            sessionsByFrameID: sessions
        )

        XCTAssertEqual(outcome, .proceed)
    }

    func testEvaluateRequiresReviewWhenAnyPendingCandidateExists() throws {
        let firstFrame = UUID()
        let secondFrame = UUID()
        let resolved = makeCandidate(reviewState: .acceptedSuggested)
        let pending = makeCandidate()
        let sessions = [
            firstFrame: CutWorkspaceGapReviewFrameSession(
                frameID: firstFrame,
                candidates: [resolved]
            ),
            secondFrame: CutWorkspaceGapReviewFrameSession(
                frameID: secondFrame,
                candidates: [pending]
            ),
        ]

        let outcome = CutWorkspaceTrackingPreflightGate.evaluate(
            frameOrder: [firstFrame, secondFrame],
            sessionsByFrameID: sessions
        )

        guard case let .requiresReview(summary, firstUnresolved) = outcome else {
            return XCTFail("Expected requiresReview, got \(outcome)")
        }
        XCTAssertEqual(summary.unresolvedGapCandidates, 1)
        XCTAssertEqual(summary.unreviewedSuggestedCorrections, 1)
        XCTAssertEqual(
            firstUnresolved,
            CutGapReviewCursor(frameID: secondFrame, candidateID: pending.id)
        )
    }

    func testRouteToReviewClearsPriorSelectionsAndLandsOnFirstPending() {
        let firstFrame = UUID()
        let secondFrame = UUID()
        let firstPending = makeCandidate()
        let secondPending = makeCandidate()
        let sessions = [
            firstFrame: CutWorkspaceGapReviewFrameSession(
                frameID: firstFrame,
                candidates: [firstPending]
            ),
            secondFrame: CutWorkspaceGapReviewFrameSession(
                frameID: secondFrame,
                candidates: [secondPending],
                selectedCandidateID: secondPending.id
            ),
        ]

        let route = CutWorkspaceTrackingPreflightGate.routeToReview(
            frameOrder: [firstFrame, secondFrame],
            sessionsByFrameID: sessions
        )

        XCTAssertEqual(route.activeFrameID, firstFrame)
        XCTAssertEqual(
            route.cursor,
            CutGapReviewCursor(frameID: firstFrame, candidateID: firstPending.id)
        )
        XCTAssertNil(route.sessionsByFrameID[secondFrame]?.selectedCandidateID)
    }

    func testRouteToReviewReturnsNilCursorWhenNothingPending() {
        let frameID = UUID()
        let resolved = makeCandidate(reviewState: .ignored)
        let sessions = [
            frameID: CutWorkspaceGapReviewFrameSession(
                frameID: frameID,
                candidates: [resolved],
                selectedCandidateID: resolved.id
            ),
        ]

        let route = CutWorkspaceTrackingPreflightGate.routeToReview(
            frameOrder: [frameID],
            sessionsByFrameID: sessions
        )

        XCTAssertNil(route.activeFrameID)
        XCTAssertNil(route.cursor)
        XCTAssertNil(route.sessionsByFrameID[frameID]?.selectedCandidateID)
    }

    private func makeCandidate(
        id: UUID = UUID(),
        reviewState: GapReviewCandidateState = .pending,
        suggestedColor: RGBAColor? = RGBAColor(red: 0.5, green: 0.5, blue: 0.5)
    ) -> GapReviewCandidatePresentation {
        GapReviewCandidatePresentation(
            id: id,
            area: 4,
            pixelCount: 4,
            confidence: 0.8,
            suggestedColor: suggestedColor,
            reviewState: reviewState
        )
    }
}
