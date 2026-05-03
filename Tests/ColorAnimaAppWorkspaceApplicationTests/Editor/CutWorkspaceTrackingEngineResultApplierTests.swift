import CoreGraphics
import XCTest
@testable import ColorAnimaAppWorkspaceApplication

final class CutWorkspaceTrackingEngineResultApplierTests: XCTestCase {
    func testApplyRunResultWritesRecordsAndPropagatedAssignments() {
        let frameID = UUID()
        let assignedRegionID = UUID()
        let unresolvedRegionID = UUID()
        let manualRegionID = UUID()
        let assignment = makeAssignment(statusName: "inked")
        let manualAssignment = makeAssignment(statusName: "manual")
        let snapshot = makeFrame(
            id: frameID,
            regions: [
                makeRegion(id: assignedRegionID),
                makeRegion(id: unresolvedRegionID),
                makeRegion(id: manualRegionID, assignment: manualAssignment),
            ]
        )
        var frames = [snapshot]

        let application = CutWorkspaceTrackingEngineResultApplier.applyRunResult(
            TrackingRunResultState(frameResults: [
                TrackingResultFrameState(
                    id: frameID,
                    reviewState: .reviewNeeded,
                    records: [
                        TrackingResultRecordState(
                            targetRegionID: assignedRegionID,
                            reviewState: .reviewNeeded,
                            confidenceValue: 0.62,
                            reasonCodes: [.lowMargin],
                            assignedRegion: assignment
                        ),
                        TrackingResultRecordState(
                            targetRegionID: unresolvedRegionID,
                            reviewState: .unresolved,
                            confidenceValue: 0.2,
                            reasonCodes: [.insufficientSupport]
                        ),
                        TrackingResultRecordState(
                            targetRegionID: manualRegionID,
                            reviewState: .tracked,
                            isManualCorrection: true,
                            assignedRegion: assignment
                        ),
                    ]
                ),
            ]),
            snapshotFrames: [snapshot],
            to: &frames
        )

        XCTAssertEqual(application.updatedFrameIDs, [frameID])
        XCTAssertEqual(frames[0].trackingRecords.map(\.regionID), [
            assignedRegionID,
            unresolvedRegionID,
            manualRegionID,
        ])
        XCTAssertEqual(
            frames[0].regions.first { $0.id == assignedRegionID }?.assignment,
            assignment
        )
        XCTAssertNil(frames[0].regions.first { $0.id == unresolvedRegionID }?.assignment)
        XCTAssertEqual(
            frames[0].regions.first { $0.id == manualRegionID }?.assignment,
            manualAssignment
        )
    }

    func testApplyRunResultBuildsCompletedSessionStateAndReviewQueue() {
        let firstFrameID = UUID()
        let secondFrameID = UUID()
        let trackedRegionID = UUID()
        let reviewRegionID = UUID()
        let unresolvedRegionID = UUID()
        let promotedAnchorID = UUID()
        let snapshots = [
            makeFrame(id: firstFrameID, orderIndex: 0, regions: [
                makeRegion(id: trackedRegionID),
                makeRegion(id: reviewRegionID),
            ]),
            makeFrame(id: secondFrameID, orderIndex: 1, regions: [
                makeRegion(id: unresolvedRegionID),
            ]),
        ]
        var frames = snapshots

        let application = CutWorkspaceTrackingEngineResultApplier.applyRunResult(
            TrackingRunResultState(
                frameResults: [
                    TrackingResultFrameState(
                        id: secondFrameID,
                        reviewState: .unresolved,
                        records: [
                            TrackingResultRecordState(
                                targetRegionID: unresolvedRegionID,
                                reviewState: .unresolved,
                                reasonCodes: [.insufficientSupport]
                            ),
                        ]
                    ),
                    TrackingResultFrameState(
                        id: firstFrameID,
                        reviewState: .reviewNeeded,
                        records: [
                            TrackingResultRecordState(
                                targetRegionID: trackedRegionID,
                                reviewState: .tracked,
                                assignedRegion: makeAssignment()
                            ),
                            TrackingResultRecordState(
                                targetRegionID: reviewRegionID,
                                reviewState: .reviewNeeded,
                                reasonCodes: [.split],
                                assignedRegion: makeAssignment()
                            ),
                        ]
                    ),
                ],
                promotedAnchorFrameIDs: [promotedAnchorID]
            ),
            snapshotFrames: snapshots,
            to: &frames
        )

        XCTAssertEqual(application.updatedFrameIDs, [firstFrameID, secondFrameID])
        XCTAssertEqual(application.unresolvedFrameIDs, [secondFrameID])
        XCTAssertEqual(application.sessionState.runStatus, .completed)
        XCTAssertEqual(application.sessionState.promotedAnchorFrameIDs, [promotedAnchorID])
        XCTAssertEqual(application.sessionState.excludedAnchorFrameIDs, [secondFrameID])
        XCTAssertEqual(application.sessionState.lastRunResult?.reviewItemCount, 2)
        XCTAssertEqual(application.sessionState.regionQueueItems.map(\.regionID), [
            reviewRegionID,
            unresolvedRegionID,
        ])
        XCTAssertEqual(application.sessionState.regionQueueItems.last?.reviewState, .unresolved)
    }

    func testApplyRunResultUsesSnapshotFrameForReplacement() {
        let frameID = UUID()
        let originalRegionID = UUID()
        let lateRegionID = UUID()
        let snapshot = makeFrame(id: frameID, regions: [makeRegion(id: originalRegionID)])
        var frames = [
            makeFrame(id: frameID, regions: [
                makeRegion(id: originalRegionID),
                makeRegion(id: lateRegionID),
            ]),
        ]

        CutWorkspaceTrackingEngineResultApplier.applyRunResult(
            TrackingRunResultState(frameResults: [
                TrackingResultFrameState(
                    id: frameID,
                    reviewState: .tracked,
                    records: [
                        TrackingResultRecordState(
                            targetRegionID: originalRegionID,
                            reviewState: .tracked,
                            assignedRegion: makeAssignment()
                        ),
                    ]
                ),
            ]),
            snapshotFrames: [snapshot],
            to: &frames
        )

        XCTAssertEqual(frames[0].regions.map(\.id), [originalRegionID])
    }

    func testApplyRunResultIgnoresFramesMissingFromSnapshotOrTarget() {
        let snapshotFrameID = UUID()
        let resultOnlyFrameID = UUID()
        let missingTargetFrameID = UUID()
        let snapshot = makeFrame(id: snapshotFrameID, regions: [makeRegion(id: UUID())])
        let missingTargetSnapshot = makeFrame(id: missingTargetFrameID, regions: [makeRegion(id: UUID())])
        var frames = [snapshot]

        let application = CutWorkspaceTrackingEngineResultApplier.applyRunResult(
            TrackingRunResultState(frameResults: [
                TrackingResultFrameState(
                    id: snapshotFrameID,
                    reviewState: .tracked,
                    records: []
                ),
                TrackingResultFrameState(
                    id: resultOnlyFrameID,
                    reviewState: .tracked,
                    records: []
                ),
                TrackingResultFrameState(
                    id: missingTargetFrameID,
                    reviewState: .tracked,
                    records: []
                ),
            ]),
            snapshotFrames: [snapshot, missingTargetSnapshot],
            to: &frames
        )

        XCTAssertEqual(application.updatedFrameIDs, [snapshotFrameID])
        XCTAssertEqual(frames.map(\.id), [snapshotFrameID])
    }

    func testApplyCancelledRunUpdatesSessionStatus() {
        var sessionState: CutWorkspaceTrackingSessionState? = CutWorkspaceTrackingSessionState(
            runStatus: .running(message: "Tracking", current: 1, total: 3),
            lastRunResult: TrackingRunResult(reviewItemCount: 2)
        )

        let updated = CutWorkspaceTrackingEngineResultApplier.applyCancelledRun(
            framesProcessed: -1,
            framesTotal: 3,
            to: &sessionState
        )

        XCTAssertEqual(updated.runStatus, .cancelled(framesProcessed: 0, framesTotal: 3))
        XCTAssertEqual(sessionState?.runStatus, .cancelled(framesProcessed: 0, framesTotal: 3))
        XCTAssertEqual(sessionState?.lastRunResult?.reviewItemCount, 2)
    }

    private func makeFrame(
        id: UUID = UUID(),
        orderIndex: Int = 0,
        regions: [TrackingInputRegionState]
    ) -> TrackingInputFrameState {
        TrackingInputFrameState(
            id: id,
            orderIndex: orderIndex,
            regions: regions
        )
    }

    private func makeRegion(
        id: UUID,
        assignment: AssignmentSyncAssignment? = nil
    ) -> TrackingInputRegionState {
        TrackingInputRegionState(
            region: CanvasSelectionRegion(
                id: id,
                area: 4,
                boundingBox: CGRect(x: 0, y: 0, width: 2, height: 2),
                pixelIndices: [0, 1, 2, 3]
            ),
            assignment: assignment
        )
    }

    private func makeAssignment(statusName: String = "base") -> AssignmentSyncAssignment {
        AssignmentSyncAssignment(
            groupID: UUID(),
            subsetID: UUID(),
            statusName: statusName
        )
    }
}
