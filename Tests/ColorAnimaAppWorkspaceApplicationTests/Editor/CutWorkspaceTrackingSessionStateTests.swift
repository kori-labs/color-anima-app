import ColorAnimaAppWorkspaceApplication
import XCTest

final class CutWorkspaceTrackingSessionStateTests: XCTestCase {
    func testRunStatusProgressMessagesMatchCurrentState() {
        XCTAssertNil(TrackingRunStatus.idle.progressMessage)
        XCTAssertEqual(TrackingRunStatus.launching.progressMessage, "Launching...")
        XCTAssertEqual(
            TrackingRunStatus.running(message: "Tracking", current: 2, total: 5).progressMessage,
            "Tracking (2/5)"
        )
        XCTAssertEqual(
            TrackingRunStatus.running(message: "Tracking", current: nil, total: nil).progressMessage,
            "Tracking"
        )
        XCTAssertEqual(TrackingRunStatus.cancelling.progressMessage, "Cancelling...")
        XCTAssertEqual(
            TrackingRunStatus.cancelled(framesProcessed: 3, framesTotal: 5).progressMessage,
            "3/5 frames processed"
        )
        XCTAssertEqual(TrackingRunStatus.failed(message: "No frames").progressMessage, "No frames")
        XCTAssertNil(TrackingRunStatus.completed.progressMessage)
    }

    func testRunResultClampsNegativeReviewCount() {
        let result = TrackingRunResult(reviewItemCount: -1)

        XCTAssertEqual(result.reviewItemCount, 0)
    }

    func testStateNormalizesPromotedAndExcludedAnchorIDs() {
        let high = UUID(uuidString: "00000000-0000-4000-8000-000000000002")!
        let low = UUID(uuidString: "00000000-0000-4000-8000-000000000001")!

        let state = CutWorkspaceTrackingSessionState(
            promotedAnchorFrameIDs: [high, low, high],
            excludedAnchorFrameIDs: [high, low, low]
        )

        XCTAssertEqual(state.promotedAnchorFrameIDs, [low, high])
        XCTAssertEqual(state.excludedAnchorFrameIDs, [low, high])
    }

    func testCancelRunIfActiveTransitionsRunningToCancellingAndLaunchingToIdle() {
        var running = CutWorkspaceTrackingSessionState(
            runStatus: .running(message: "Tracking", current: nil, total: nil)
        )
        running.cancelRunIfActive()
        XCTAssertEqual(running.runStatus, .cancelling)

        var launching = CutWorkspaceTrackingSessionState(runStatus: .launching)
        launching.cancelRunIfActive()
        XCTAssertEqual(launching.runStatus, .idle)

        var completed = CutWorkspaceTrackingSessionState(runStatus: .completed)
        completed.cancelRunIfActive()
        XCTAssertEqual(completed.runStatus, .completed)
    }

    func testIsRunningIncludesLaunchingRunningAndCancelling() {
        XCTAssertTrue(CutWorkspaceTrackingSessionState(runStatus: .launching).isRunning)
        XCTAssertTrue(
            CutWorkspaceTrackingSessionState(
                runStatus: .running(message: "Tracking", current: 1, total: 2)
            ).isRunning
        )
        XCTAssertTrue(CutWorkspaceTrackingSessionState(runStatus: .cancelling).isRunning)
        XCTAssertFalse(CutWorkspaceTrackingSessionState(runStatus: .idle).isRunning)
        XCTAssertFalse(CutWorkspaceTrackingSessionState(runStatus: .completed).isRunning)
    }

    func testQueueCursorAndCurrentItemClampToAvailableQueue() {
        let first = makeItem()
        let second = makeItem()
        let state = CutWorkspaceTrackingSessionState(
            queueState: CutWorkspaceTrackingQueueState(
                queueItems: [first, second],
                queueIndex: 9
            )
        )

        XCTAssertEqual(state.clampedQueueIndex, 1)
        XCTAssertEqual(state.queueCursor, TrackingQueueCursor(currentIndex: 1, totalCount: 2))
        XCTAssertEqual(state.currentQueueItem, second)
        XCTAssertEqual(state.regionQueueItems, [first, second])
    }

    func testQueueCursorIsNilWhenQueueIsMissingOrEmpty() {
        XCTAssertNil(CutWorkspaceTrackingSessionState().queueCursor)
        XCTAssertNil(
            CutWorkspaceTrackingSessionState(
                queueState: CutWorkspaceTrackingQueueState(queueItems: [])
            ).queueCursor
        )
    }

    func testUpdatingQueueCursorOnlyMutatesQueueIndexWhenQueueExists() {
        let item = makeItem()
        let state = CutWorkspaceTrackingSessionState(
            queueState: CutWorkspaceTrackingQueueState(queueItems: [item], queueIndex: 0)
        )

        XCTAssertEqual(state.updatingQueueCursor(3).queueState?.queueIndex, 3)
        XCTAssertNil(CutWorkspaceTrackingSessionState().updatingQueueCursor(3).queueState)
    }

    func testRemovingQueueItemDropsMatchingRegionAndClampsQueueIndex() {
        let first = makeItem()
        let second = makeItem()
        let state = CutWorkspaceTrackingSessionState(
            queueState: CutWorkspaceTrackingQueueState(
                queueItems: [first, second],
                queueIndex: 1
            )
        )

        let updated = state.removingQueueItem(
            frameID: second.frameID,
            regionID: second.regionID
        )

        XCTAssertEqual(updated.regionQueueItems, [first])
        XCTAssertEqual(updated.queueState?.queueIndex, 0)
    }

    func testHasRunOnceReflectsLastRunResultPresence() {
        XCTAssertFalse(CutWorkspaceTrackingSessionState().hasRunOnce)
        XCTAssertTrue(
            CutWorkspaceTrackingSessionState(
                lastRunResult: TrackingRunResult(updatedFrameIDs: [UUID()])
            ).hasRunOnce
        )
    }

    private func makeItem() -> CutWorkspaceTrackingQueueItemState {
        CutWorkspaceTrackingQueueItemState(
            frameID: UUID(),
            regionID: UUID(),
            reviewState: .reviewNeeded
        )
    }
}
