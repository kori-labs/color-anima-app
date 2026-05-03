import XCTest
@testable import ColorAnimaAppWorkspaceApplication

final class CutWorkspaceTrackingManualCorrectionTests: XCTestCase {
    func testCanAcceptRequiresResolvedNonManualQueueItem() {
        let fixture = makeQueueFixture(firstHasResolvedAssignment: true)

        XCTAssertTrue(
            CutWorkspaceTrackingManualCorrection.canAcceptQueueItem(
                frameID: fixture.firstFrameID,
                regionID: fixture.firstRegionID,
                in: fixture.sessionState,
                frames: fixture.frames
            )
        )

        let unresolved = makeQueueFixture(firstHasResolvedAssignment: false)
        XCTAssertFalse(
            CutWorkspaceTrackingManualCorrection.canAcceptQueueItem(
                frameID: unresolved.firstFrameID,
                regionID: unresolved.firstRegionID,
                in: unresolved.sessionState,
                frames: unresolved.frames
            )
        )

        let manual = makeQueueFixture(firstHasResolvedAssignment: true, firstIsManualOverride: true)
        XCTAssertFalse(
            CutWorkspaceTrackingManualCorrection.canAcceptQueueItem(
                frameID: manual.firstFrameID,
                regionID: manual.firstRegionID,
                in: manual.sessionState,
                frames: manual.frames
            )
        )
    }

    func testCanReassignRequiresSelectedSubsetAndNonManualQueueItem() {
        let fixture = makeQueueFixture()
        let subsetID = UUID()

        XCTAssertTrue(
            CutWorkspaceTrackingManualCorrection.canReassignQueueItem(
                frameID: fixture.firstFrameID,
                regionID: fixture.firstRegionID,
                selectedSubsetID: subsetID,
                in: fixture.sessionState,
                frames: fixture.frames
            )
        )
        XCTAssertFalse(
            CutWorkspaceTrackingManualCorrection.canReassignQueueItem(
                frameID: fixture.firstFrameID,
                regionID: fixture.firstRegionID,
                selectedSubsetID: nil,
                in: fixture.sessionState,
                frames: fixture.frames
            )
        )

        let manual = makeQueueFixture(firstIsManualOverride: true)
        XCTAssertFalse(
            CutWorkspaceTrackingManualCorrection.canReassignQueueItem(
                frameID: manual.firstFrameID,
                regionID: manual.firstRegionID,
                selectedSubsetID: subsetID,
                in: manual.sessionState,
                frames: manual.frames
            )
        )
    }

    func testApplyCurrentQueueAcceptanceRunsCallbackRemovesItemAndRefreshes() {
        let fixture = makeQueueFixture(firstHasResolvedAssignment: true)
        var sessionState = fixture.sessionState
        var capturedTarget: CutWorkspaceTrackingManualCorrection.ManualCorrectionTarget?
        var capturedPromoteFlag: Bool?
        var refreshCount = 0

        let application = CutWorkspaceTrackingManualCorrection.applyCurrentQueueAcceptance(
            promoteToAnchor: true,
            in: &sessionState,
            frames: fixture.frames,
            applyAcceptance: { target, promoteToAnchor in
                capturedTarget = target
                capturedPromoteFlag = promoteToAnchor
                return true
            },
            refreshOverlay: { refreshCount += 1 }
        )

        XCTAssertEqual(capturedTarget?.frameID, fixture.firstFrameID)
        XCTAssertEqual(capturedTarget?.regionID, fixture.firstRegionID)
        XCTAssertEqual(capturedPromoteFlag, true)
        XCTAssertEqual(application?.request.kind, .acceptance)
        XCTAssertEqual(application?.removedQueueItem, true)
        XCTAssertEqual(application?.remainingQueueItemCount, 1)
        XCTAssertEqual(sessionState.currentQueueItem?.frameID, fixture.secondFrameID)
        XCTAssertEqual(refreshCount, 1)
    }

    func testApplyCurrentQueueAcceptanceLeavesStateOnCallbackFailure() {
        let fixture = makeQueueFixture(firstHasResolvedAssignment: true)
        var sessionState = fixture.sessionState
        var refreshCount = 0

        let application = CutWorkspaceTrackingManualCorrection.applyCurrentQueueAcceptance(
            in: &sessionState,
            frames: fixture.frames,
            applyAcceptance: { _, _ in false },
            refreshOverlay: { refreshCount += 1 }
        )

        XCTAssertNil(application)
        XCTAssertEqual(sessionState, fixture.sessionState)
        XCTAssertEqual(refreshCount, 0)
    }

    func testApplyCurrentQueueReassignmentPassesSelectionAndRemovesItem() {
        let fixture = makeQueueFixture()
        var sessionState = fixture.sessionState
        let subsetID = UUID()
        let groupID = UUID()
        var capturedSelection: CutWorkspaceTrackingManualCorrection.ManualReassignmentSelection?
        var capturedPromoteFlag: Bool?

        let application = CutWorkspaceTrackingManualCorrection.applyCurrentQueueReassignment(
            subsetID: subsetID,
            groupID: groupID,
            statusName: "clean",
            promoteToAnchor: true,
            in: &sessionState,
            frames: fixture.frames,
            applyReassignment: { target, selection, promoteToAnchor in
                XCTAssertEqual(target.frameID, fixture.firstFrameID)
                XCTAssertEqual(target.regionID, fixture.firstRegionID)
                capturedSelection = selection
                capturedPromoteFlag = promoteToAnchor
                return true
            },
            refreshOverlay: {}
        )

        XCTAssertEqual(
            capturedSelection,
            CutWorkspaceTrackingManualCorrection.ManualReassignmentSelection(
                subsetID: subsetID,
                groupID: groupID,
                statusName: "clean"
            )
        )
        XCTAssertEqual(capturedPromoteFlag, true)
        XCTAssertEqual(
            application?.request.kind,
            .reassignment(
                CutWorkspaceTrackingManualCorrection.ManualReassignmentSelection(
                    subsetID: subsetID,
                    groupID: groupID,
                    statusName: "clean"
                )
            )
        )
        XCTAssertEqual(sessionState.regionQueueItems.map(\.frameID), [fixture.secondFrameID])
    }

    func testApplyTrackingManualCorrectionCanRemoveNonCurrentQueuedTarget() {
        let fixture = makeQueueFixture()
        var sessionState = fixture.sessionState
        let target = CutWorkspaceTrackingManualCorrection.ManualCorrectionTarget(
            frameID: fixture.secondFrameID,
            regionID: fixture.secondRegionID
        )

        let application = CutWorkspaceTrackingManualCorrection.applyTrackingManualCorrection(
            target: target,
            kind: .acceptance,
            in: &sessionState,
            applyCorrection: { request in
                XCTAssertEqual(request.target, target)
                return true
            },
            refreshOverlay: {}
        )

        XCTAssertEqual(application?.removedQueueItem, true)
        XCTAssertEqual(application?.remainingQueueItemCount, 1)
        XCTAssertEqual(sessionState.currentQueueItem?.frameID, fixture.firstFrameID)
    }

    private func makeQueueFixture(
        firstHasResolvedAssignment: Bool = false,
        firstIsManualOverride: Bool = false
    ) -> QueueFixture {
        let firstFrameID = UUID()
        let secondFrameID = UUID()
        let firstRegionID = UUID()
        let secondRegionID = UUID()
        let frames = [
            CutWorkspaceTrackingQueueFrame(
                id: firstFrameID,
                orderIndex: 0,
                regions: [
                    CutWorkspaceTrackingQueueRegion(
                        id: firstRegionID,
                        displayName: "Face",
                        isManualOverride: firstIsManualOverride
                    )
                ]
            ),
            CutWorkspaceTrackingQueueFrame(
                id: secondFrameID,
                orderIndex: 1,
                regions: [
                    CutWorkspaceTrackingQueueRegion(id: secondRegionID, displayName: "Hair")
                ]
            ),
        ]
        let sessionState = CutWorkspaceTrackingSessionState(
            queueState: CutWorkspaceTrackingQueueState(
                queueItems: [
                    CutWorkspaceTrackingQueueItemState(
                        frameID: firstFrameID,
                        regionID: firstRegionID,
                        reviewState: .reviewNeeded,
                        hasResolvedAssignment: firstHasResolvedAssignment
                    ),
                    CutWorkspaceTrackingQueueItemState(
                        frameID: secondFrameID,
                        regionID: secondRegionID,
                        reviewState: .unresolved,
                        hasResolvedAssignment: true
                    ),
                ]
            )
        )

        return QueueFixture(
            firstFrameID: firstFrameID,
            secondFrameID: secondFrameID,
            firstRegionID: firstRegionID,
            secondRegionID: secondRegionID,
            frames: frames,
            sessionState: sessionState
        )
    }

    private struct QueueFixture {
        let firstFrameID: UUID
        let secondFrameID: UUID
        let firstRegionID: UUID
        let secondRegionID: UUID
        let frames: [CutWorkspaceTrackingQueueFrame]
        let sessionState: CutWorkspaceTrackingSessionState
    }
}
