import XCTest
@testable import ColorAnimaAppWorkspaceApplication

final class CutWorkspaceTrackingInteractionCoordinatorTests: XCTestCase {
    func testNavigateToQueueItemMovesCursorAndReturnsFocusTarget() {
        let fixture = makeQueueFixture()
        var state: CutWorkspaceTrackingQueueState? = fixture.state

        let focus = CutWorkspaceTrackingInteractionCoordinator.navigateToQueueItem(
            at: 1,
            queueState: &state,
            frames: fixture.frames
        )

        XCTAssertEqual(state?.queueIndex, 1)
        XCTAssertEqual(
            focus,
            CutWorkspaceTrackingInteractionCoordinator.TrackingFocusTarget(
                frameID: fixture.secondFrameID,
                regionID: fixture.secondRegionID
            )
        )
    }

    func testSkipCurrentQueueItemAdvancesToNextItem() {
        let fixture = makeQueueFixture()
        var state: CutWorkspaceTrackingQueueState? = fixture.state

        let focus = CutWorkspaceTrackingInteractionCoordinator.skipCurrentQueueItem(
            queueState: &state,
            frames: fixture.frames
        )

        XCTAssertEqual(state?.queueIndex, 1)
        XCTAssertEqual(focus?.frameID, fixture.secondFrameID)
        XCTAssertEqual(focus?.regionID, fixture.secondRegionID)
    }

    func testAcceptCurrentQueueItemRunsCallbacksAndReturnsCurrentFocus() {
        let fixture = makeQueueFixture()
        var accepted = false
        var refreshed = false

        let focus = CutWorkspaceTrackingInteractionCoordinator.acceptCurrentQueueItem(
            queueState: fixture.state,
            frames: fixture.frames,
            applyAcceptance: { accepted = true },
            refreshOverlay: { refreshed = true }
        )

        XCTAssertTrue(accepted)
        XCTAssertTrue(refreshed)
        XCTAssertEqual(focus?.frameID, fixture.firstFrameID)
        XCTAssertEqual(focus?.regionID, fixture.firstRegionID)
    }

    func testReassignCurrentQueueItemPassesSelectionArguments() {
        let fixture = makeQueueFixture()
        let subsetID = UUID()
        let groupID = UUID()
        var captured: (UUID, UUID, String)?
        var refreshed = false

        _ = CutWorkspaceTrackingInteractionCoordinator.reassignCurrentQueueItem(
            subsetID: subsetID,
            groupID: groupID,
            statusName: "clean",
            queueState: fixture.state,
            frames: fixture.frames,
            applyReassignment: { subsetID, groupID, statusName in
                captured = (subsetID, groupID, statusName)
            },
            refreshOverlay: { refreshed = true }
        )

        XCTAssertEqual(captured?.0, subsetID)
        XCTAssertEqual(captured?.1, groupID)
        XCTAssertEqual(captured?.2, "clean")
        XCTAssertTrue(refreshed)
    }

    func testSelectedTrackingContextRequiresSelectedIDsAndAvailableContext() {
        let frameID = UUID()
        let regionID = UUID()

        XCTAssertNil(
            CutWorkspaceTrackingInteractionCoordinator.selectedTrackingContext(
                selectedFrameID: nil,
                selectedRegionID: regionID,
                hasTrackingContext: { _ in true }
            )
        )

        XCTAssertNil(
            CutWorkspaceTrackingInteractionCoordinator.selectedTrackingContext(
                selectedFrameID: frameID,
                selectedRegionID: regionID,
                hasTrackingContext: { _ in false }
            )
        )

        XCTAssertEqual(
            CutWorkspaceTrackingInteractionCoordinator.selectedTrackingContext(
                selectedFrameID: frameID,
                selectedRegionID: regionID,
                hasTrackingContext: { _ in true }
            ),
            CutWorkspaceTrackingInteractionCoordinator.TrackingFocusTarget(
                frameID: frameID,
                regionID: regionID
            )
        )
    }

    func testAcceptSelectedRegionRequiresContextResolvedAssignmentAndSuccessfulApply() {
        let frameID = UUID()
        let regionID = UUID()
        var appliedPromoteFlag: Bool?
        var refreshed = false

        let missingAssignment = CutWorkspaceTrackingInteractionCoordinator.acceptSelectedRegionTracking(
            selectedFrameID: frameID,
            selectedRegionID: regionID,
            promoteToAnchor: true,
            hasTrackingContext: { _ in true },
            hasResolvedAssignment: { _ in false },
            applyAcceptance: { _, promoteToAnchor in
                appliedPromoteFlag = promoteToAnchor
                return true
            },
            refreshOverlay: { refreshed = true }
        )

        XCTAssertNil(missingAssignment)
        XCTAssertNil(appliedPromoteFlag)
        XCTAssertFalse(refreshed)

        let accepted = CutWorkspaceTrackingInteractionCoordinator.acceptSelectedRegionTracking(
            selectedFrameID: frameID,
            selectedRegionID: regionID,
            promoteToAnchor: true,
            hasTrackingContext: { _ in true },
            hasResolvedAssignment: { _ in true },
            applyAcceptance: { _, promoteToAnchor in
                appliedPromoteFlag = promoteToAnchor
                return true
            },
            refreshOverlay: { refreshed = true }
        )

        XCTAssertEqual(accepted?.frameID, frameID)
        XCTAssertEqual(accepted?.regionID, regionID)
        XCTAssertEqual(appliedPromoteFlag, true)
        XCTAssertTrue(refreshed)
    }

    func testApplyTrackingReassignmentOnlyRefreshesOnSuccess() {
        let frameID = UUID()
        let regionID = UUID()
        let subsetID = UUID()
        let groupID = UUID()
        var refreshCount = 0

        let failed = CutWorkspaceTrackingInteractionCoordinator.applyTrackingReassignmentIfAvailable(
            frameID: frameID,
            regionID: regionID,
            subsetID: subsetID,
            groupID: groupID,
            statusName: "clean",
            applyReassignment: { _, _, _, _ in false },
            refreshOverlay: { refreshCount += 1 }
        )

        let succeeded = CutWorkspaceTrackingInteractionCoordinator.applyTrackingReassignmentIfAvailable(
            frameID: frameID,
            regionID: regionID,
            subsetID: subsetID,
            groupID: groupID,
            statusName: "clean",
            applyReassignment: { target, capturedSubset, capturedGroup, capturedStatus in
                XCTAssertEqual(target.frameID, frameID)
                XCTAssertEqual(target.regionID, regionID)
                XCTAssertEqual(capturedSubset, subsetID)
                XCTAssertEqual(capturedGroup, groupID)
                XCTAssertEqual(capturedStatus, "clean")
                return true
            },
            refreshOverlay: { refreshCount += 1 }
        )

        XCTAssertFalse(failed)
        XCTAssertTrue(succeeded)
        XCTAssertEqual(refreshCount, 1)
    }

    func testMarkSelectedRegionUnresolvedAndSplitOverrideRequireSuccessfulApply() {
        let frameID = UUID()
        let regionID = UUID()
        var refreshCount = 0

        let unresolved = CutWorkspaceTrackingInteractionCoordinator.markSelectedRegionUnresolved(
            selectedFrameID: frameID,
            selectedRegionID: regionID,
            hasTrackingContext: { _ in true },
            applyUnresolved: { target in
                XCTAssertEqual(target.regionID, regionID)
                return true
            },
            refreshOverlay: { refreshCount += 1 }
        )

        let split = CutWorkspaceTrackingInteractionCoordinator.applyTrackingSplitOverrideIfAvailable(
            for: .highlight,
            selectedFrameID: frameID,
            selectedRegionID: regionID,
            hasTrackingContext: { _ in true },
            applySplitOverride: { target, role in
                XCTAssertEqual(target.frameID, frameID)
                XCTAssertEqual(role, .highlight)
                return true
            },
            refreshOverlay: { refreshCount += 1 }
        )

        XCTAssertEqual(unresolved?.frameID, frameID)
        XCTAssertTrue(split)
        XCTAssertEqual(refreshCount, 2)
    }

    private func makeQueueFixture() -> QueueFixture {
        let firstFrameID = UUID()
        let secondFrameID = UUID()
        let firstRegionID = UUID()
        let secondRegionID = UUID()
        let frames = [
            CutWorkspaceTrackingQueueFrame(
                id: firstFrameID,
                orderIndex: 0,
                regions: [
                    CutWorkspaceTrackingQueueRegion(id: firstRegionID, displayName: "Face")
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
        let state = CutWorkspaceTrackingQueueState(
            queueItems: [
                CutWorkspaceTrackingQueueItemState(
                    frameID: firstFrameID,
                    regionID: firstRegionID,
                    reviewState: .reviewNeeded
                ),
                CutWorkspaceTrackingQueueItemState(
                    frameID: secondFrameID,
                    regionID: secondRegionID,
                    reviewState: .unresolved
                ),
            ]
        )
        return QueueFixture(
            firstFrameID: firstFrameID,
            secondFrameID: secondFrameID,
            firstRegionID: firstRegionID,
            secondRegionID: secondRegionID,
            frames: frames,
            state: state
        )
    }

    private struct QueueFixture {
        let firstFrameID: UUID
        let secondFrameID: UUID
        let firstRegionID: UUID
        let secondRegionID: UUID
        let frames: [CutWorkspaceTrackingQueueFrame]
        let state: CutWorkspaceTrackingQueueState
    }
}
