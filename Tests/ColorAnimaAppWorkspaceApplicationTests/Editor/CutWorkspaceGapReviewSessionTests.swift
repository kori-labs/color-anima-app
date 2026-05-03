import ColorAnimaAppWorkspaceApplication
import XCTest

final class CutWorkspaceGapReviewSessionTests: XCTestCase {
    func testFreshSessionWithoutSelectionExposesCandidatesAsUnresolved() {
        let candidates = makeCandidates(count: 3)
        let session = CutWorkspaceGapReviewFrameSession(
            frameID: UUID(),
            candidates: candidates
        )

        XCTAssertEqual(session.candidates.count, 3)
        XCTAssertNil(session.selectedCandidateID)
        XCTAssertEqual(session.unresolvedCount, 3)
        XCTAssertEqual(session.preflightSummary.unresolvedGapCandidates, 3)
        XCTAssertTrue(session.preflightSummary.hasUnresolvedReviewState)
    }

    func testStaleSelectionIsRejectedAtConstruction() {
        let candidates = makeCandidates(count: 2)
        let session = CutWorkspaceGapReviewFrameSession(
            frameID: UUID(),
            candidates: candidates,
            selectedCandidateID: UUID()
        )

        XCTAssertNil(session.selectedCandidateID)
    }

    func testSelectAcceptsKnownIDsAndClearsUnknownIDs() {
        let candidates = makeCandidates(count: 2)
        var session = CutWorkspaceGapReviewFrameSession(
            frameID: UUID(),
            candidates: candidates
        )

        session.select(candidates[1].id)
        XCTAssertEqual(session.selectedCandidateID, candidates[1].id)

        session.select(UUID())
        XCTAssertNil(session.selectedCandidateID)
    }

    func testAdvanceToNextPendingSkipsResolvedCandidatesAndWrapsAround() {
        var candidates = makeCandidates(count: 3)
        candidates[1].reviewState = .acceptedSuggested
        var session = CutWorkspaceGapReviewFrameSession(
            frameID: UUID(),
            candidates: candidates
        )

        XCTAssertEqual(session.advanceToNextPending(), candidates[0].id)
        XCTAssertEqual(session.advanceToNextPending(), candidates[2].id)
        XCTAssertEqual(session.advanceToNextPending(), candidates[0].id)
    }

    func testAdvanceToNextPendingClearsSelectionWhenNoneRemain() {
        var candidates = makeCandidates(count: 2)
        candidates[0].reviewState = .ignored
        candidates[1].reviewState = .acceptedSuggested
        var session = CutWorkspaceGapReviewFrameSession(
            frameID: UUID(),
            candidates: candidates
        )

        XCTAssertNil(session.advanceToNextPending())
        XCTAssertNil(session.selectedCandidateID)
    }

    func testAcceptSuggestedRequiresResolvedColor() {
        var candidate = makeCandidate()
        candidate.suggestedColor = nil
        var session = CutWorkspaceGapReviewFrameSession(
            frameID: UUID(),
            candidates: [candidate]
        )

        session.acceptSuggested(candidate.id)
        XCTAssertEqual(session.candidates.first?.reviewState, .pending)

        candidate.suggestedColor = RGBAColor(red: 0.2, green: 0.4, blue: 0.6)
        session = CutWorkspaceGapReviewFrameSession(
            frameID: UUID(),
            candidates: [candidate]
        )

        session.acceptSuggested(candidate.id)
        XCTAssertEqual(session.candidates.first?.reviewState, .acceptedSuggested)
    }

    func testManualColorOverwritesSuggestionAndReviewActionsPreserveMetrics() {
        let candidate = makeCandidate()
        var session = CutWorkspaceGapReviewFrameSession(
            frameID: UUID(),
            candidates: [candidate]
        )
        let color = RGBAColor(red: 0.1, green: 0.2, blue: 0.3)

        session.applyManualColor(color, for: candidate.id)
        XCTAssertEqual(session.candidates.first?.suggestedColor, color)
        XCTAssertEqual(session.candidates.first?.reviewState, .manualColorApplied)

        session = CutWorkspaceGapReviewFrameSession(frameID: UUID(), candidates: [candidate])
        session.ignore(candidate.id)
        XCTAssertEqual(session.candidates.first?.reviewState, .ignored)

        session = CutWorkspaceGapReviewFrameSession(frameID: UUID(), candidates: [candidate])
        session.rejectSuggestion(candidate.id)
        XCTAssertEqual(session.candidates.first?.reviewState, .rejectedSuggestion)

        session = CutWorkspaceGapReviewFrameSession(frameID: UUID(), candidates: [candidate])
        session.markResolvedByRepaint(candidate.id)
        XCTAssertEqual(session.candidates.first?.reviewState, .resolvedByRepaint)
        XCTAssertEqual(session.candidates.first?.area, candidate.area)
        XCTAssertEqual(session.candidates.first?.pixelCount, candidate.pixelCount)
    }

    func testReviewActionOnUnknownIDIsNoOp() {
        let candidate = makeCandidate()
        var session = CutWorkspaceGapReviewFrameSession(
            frameID: UUID(),
            candidates: [candidate]
        )

        session.acceptSuggested(UUID())
        session.applyManualColor(.black, for: UUID())
        session.ignore(UUID())

        XCTAssertEqual(session.candidates.first?.reviewState, .pending)
    }

    func testResolveSuggestedColorsFillsCandidatesWithKnownNearestRegion() {
        let red = UUID(uuidString: "00000000-0000-4000-8000-000000000001")!
        let blue = UUID(uuidString: "00000000-0000-4000-8000-000000000002")!
        let palette: [UUID: RGBAColor] = [
            red: RGBAColor(red: 1, green: 0, blue: 0),
            blue: RGBAColor(red: 0, green: 0, blue: 1)
        ]
        let pointingAtRed = makeCandidate(nearestPaintedRegionID: red, suggestedColor: nil)
        let pointingAtUnknown = makeCandidate(nearestPaintedRegionID: UUID(), suggestedColor: nil)
        let alreadyResolved = makeCandidate(nearestPaintedRegionID: blue, suggestedColor: .black)

        var session = CutWorkspaceGapReviewFrameSession(
            frameID: UUID(),
            candidates: [pointingAtRed, pointingAtUnknown, alreadyResolved]
        )
        session.resolveSuggestedColors(regionColorByID: { palette[$0] })

        XCTAssertEqual(session.candidates[0].suggestedColor, palette[red])
        XCTAssertNil(session.candidates[1].suggestedColor)
        XCTAssertEqual(session.candidates[2].suggestedColor, .black)
    }

    func testPreflightSummaryDistinguishesSuggestedPendingFromBarePending() {
        let withSuggestion = makeCandidate(
            suggestedColor: RGBAColor(red: 0.2, green: 0.2, blue: 0.2)
        )
        let barePending = makeCandidate(suggestedColor: nil)
        var resolved = makeCandidate()
        resolved.reviewState = .acceptedSuggested
        let session = CutWorkspaceGapReviewFrameSession(
            frameID: UUID(),
            candidates: [withSuggestion, barePending, resolved]
        )
        let summary = session.preflightSummary

        XCTAssertEqual(summary.unresolvedGapCandidates, 2)
        XCTAssertEqual(summary.unreviewedSuggestedCorrections, 1)
        XCTAssertTrue(summary.hasUnresolvedReviewState)
    }

    func testEmptySessionHasNoUnresolvedReviewState() {
        let session = CutWorkspaceGapReviewFrameSession(frameID: UUID(), candidates: [])

        XCTAssertEqual(session.preflightSummary.unresolvedGapCandidates, 0)
        XCTAssertEqual(session.preflightSummary.unreviewedSuggestedCorrections, 0)
        XCTAssertFalse(session.preflightSummary.hasUnresolvedReviewState)
    }

    private func makeCandidates(count: Int) -> [GapReviewCandidatePresentation] {
        (0..<count).map { _ in makeCandidate() }
    }

    private func makeCandidate(
        id: UUID = UUID(),
        area: Int = 4,
        pixelCount: Int = 4,
        nearestPaintedRegionID: UUID? = UUID(),
        confidence: Double = 0.8,
        suggestedColor: RGBAColor? = RGBAColor(red: 0.5, green: 0.5, blue: 0.5),
        reviewState: GapReviewCandidateState = .pending
    ) -> GapReviewCandidatePresentation {
        GapReviewCandidatePresentation(
            id: id,
            area: area,
            pixelCount: pixelCount,
            nearestPaintedRegionID: nearestPaintedRegionID,
            confidence: confidence,
            suggestedColor: suggestedColor,
            reviewState: reviewState
        )
    }
}
