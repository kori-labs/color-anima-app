import CoreGraphics
import XCTest
@testable import ColorAnimaAppWorkspaceApplication

final class CutWorkspaceTrackingInputBuilderTests: XCTestCase {
    func testGapReviewPreflightIsNilWhenNoSessionsExist() {
        let frameID = UUID()

        let inputs = CutWorkspaceTrackingInputBuilder.makeRunInputs(
            frames: [makeFrame(id: frameID)],
            keyFrameIDs: [frameID],
            canvasResolution: ProjectCanvasResolution(width: 100, height: 100)
        )

        XCTAssertNil(inputs.gapReviewPreflight)
    }

    func testGapReviewPreflightIsZeroSummaryWhenSessionExistsButHasNoCandidates() throws {
        let frameID = UUID()

        let preflight = CutWorkspaceTrackingInputBuilder.makeRunInputs(
            frames: [makeFrame(id: frameID)],
            keyFrameIDs: [frameID],
            canvasResolution: ProjectCanvasResolution(width: 100, height: 100),
            gapReviewSessions: [
                CutWorkspaceGapReviewFrameSession(
                    frameID: frameID,
                    candidates: []
                ),
            ]
        ).gapReviewPreflight

        let summary = try XCTUnwrap(preflight)
        XCTAssertEqual(summary.unresolvedGapCandidates, 0)
        XCTAssertEqual(summary.unreviewedSuggestedCorrections, 0)
        XCTAssertFalse(summary.hasUnresolvedReviewState)
    }

    func testGapReviewPreflightAggregatesCountsAcrossFrames() throws {
        let frameA = UUID()
        let frameB = UUID()
        var pendingWithSuggestion = makeCandidate()
        pendingWithSuggestion.reviewState = .pending
        var bareCandidate = makeCandidate(suggestedColor: nil)
        bareCandidate.reviewState = .pending
        var resolved = makeCandidate()
        resolved.reviewState = .acceptedSuggested

        let preflight = CutWorkspaceTrackingInputBuilder.makeRunInputs(
            frames: [
                makeFrame(id: frameA, orderIndex: 0),
                makeFrame(id: frameB, orderIndex: 1),
            ],
            keyFrameIDs: [frameA],
            canvasResolution: ProjectCanvasResolution(width: 100, height: 100),
            gapReviewSessions: [
                CutWorkspaceGapReviewFrameSession(
                    frameID: frameA,
                    candidates: [pendingWithSuggestion, resolved]
                ),
                CutWorkspaceGapReviewFrameSession(
                    frameID: frameB,
                    candidates: [bareCandidate]
                ),
            ]
        ).gapReviewPreflight

        let summary = try XCTUnwrap(preflight)
        XCTAssertEqual(summary.unresolvedGapCandidates, 2)
        XCTAssertEqual(summary.unreviewedSuggestedCorrections, 1)
        XCTAssertTrue(summary.hasUnresolvedReviewState)
    }

    func testSnapshotSortsFramesAndReportsCanvasResolution() {
        let later = UUID()
        let earlier = UUID()

        let inputs = CutWorkspaceTrackingInputBuilder.makeRunInputs(
            frames: [
                makeFrame(id: later, orderIndex: 1),
                makeFrame(id: earlier, orderIndex: 0),
            ],
            keyFrameIDs: [later, earlier],
            selectedFrameID: earlier,
            canvasResolution: ProjectCanvasResolution(width: 320, height: 240)
        )

        XCTAssertEqual(inputs.orderedFrames.map(\.id), [earlier, later])
        XCTAssertEqual(inputs.totalFrameCount, 2)
        XCTAssertEqual(inputs.canvasWidth, 320)
        XCTAssertEqual(inputs.canvasHeight, 240)
        XCTAssertEqual(inputs.preferredReferenceFrameID, earlier)
    }

    func testReferenceFramesWithoutAssignmentsAreDemotedForRunSnapshot() {
        let assignedReference = UUID()
        let unassignedReference = UUID()
        let target = UUID()

        let inputs = CutWorkspaceTrackingInputBuilder.makeRunInputs(
            frames: [
                makeFrame(id: assignedReference, orderIndex: 0, hasAssignment: true),
                makeFrame(id: unassignedReference, orderIndex: 1, hasAssignment: false),
                makeFrame(id: target, orderIndex: 2, hasAssignment: false),
            ],
            keyFrameIDs: [assignedReference, unassignedReference],
            selectedFrameID: unassignedReference,
            canvasResolution: ProjectCanvasResolution(width: 100, height: 100)
        )

        XCTAssertEqual(inputs.keyFrameIDs, [assignedReference])
        XCTAssertNil(inputs.preferredReferenceFrameID)
    }

    private func makeFrame(
        id: UUID = UUID(),
        orderIndex: Int = 0,
        hasAssignment: Bool = true
    ) -> TrackingInputFrameState {
        TrackingInputFrameState(
            id: id,
            orderIndex: orderIndex,
            regions: [
                TrackingInputRegionState(
                    region: CanvasSelectionRegion(
                        id: UUID(),
                        area: 4,
                        boundingBox: CGRect(x: 0, y: 0, width: 2, height: 2),
                        pixelIndices: [0, 1, 2, 3]
                    ),
                    assignment: hasAssignment ? makeAssignment() : nil
                ),
            ]
        )
    }

    private func makeAssignment() -> AssignmentSyncAssignment {
        AssignmentSyncAssignment(
            groupID: UUID(),
            subsetID: UUID(),
            statusName: "base"
        )
    }

    private func makeCandidate(
        suggestedColor: RGBAColor? = RGBAColor(red: 0.5, green: 0.5, blue: 0.5)
    ) -> GapReviewCandidatePresentation {
        GapReviewCandidatePresentation(
            area: 4,
            pixelCount: 4,
            nearestPaintedRegionID: UUID(),
            confidence: 0.8,
            suggestedColor: suggestedColor,
            reviewState: .pending
        )
    }
}
