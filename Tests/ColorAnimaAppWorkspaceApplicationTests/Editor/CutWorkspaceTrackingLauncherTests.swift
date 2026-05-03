import XCTest
@testable import ColorAnimaAppWorkspaceApplication

final class CutWorkspaceTrackingLauncherTests: XCTestCase {
    func testPrepareLaunchCreatesLaunchingStateWhenSessionStateIsMissing() {
        var sessionState: CutWorkspaceTrackingSessionState?

        let preparation = CutWorkspaceTrackingLauncher.prepareLaunch(in: &sessionState)

        XCTAssertEqual(preparation, .started)
        XCTAssertEqual(sessionState?.runStatus, .launching)
    }

    func testPrepareLaunchMovesExistingNonIdleStateToLaunching() {
        var sessionState: CutWorkspaceTrackingSessionState? = CutWorkspaceTrackingSessionState(
            runStatus: .completed,
            lastRunResult: TrackingRunResult(reviewItemCount: 3)
        )

        let preparation = CutWorkspaceTrackingLauncher.prepareLaunch(in: &sessionState)

        XCTAssertEqual(preparation, .started)
        XCTAssertEqual(sessionState?.runStatus, .launching)
        XCTAssertEqual(sessionState?.lastRunResult?.reviewItemCount, 3)
    }

    func testPrepareLaunchConvertsPreCancelledIdleStateToCancelled() {
        var sessionState: CutWorkspaceTrackingSessionState? = CutWorkspaceTrackingSessionState(runStatus: .idle)

        let preparation = CutWorkspaceTrackingLauncher.prepareLaunch(in: &sessionState)

        XCTAssertEqual(preparation, .cancelledBeforeStart)
        XCTAssertEqual(sessionState?.runStatus, .cancelled(framesProcessed: 0, framesTotal: 0))
    }

    func testResolveCancelledBeforeRunIfNeededConvertsIdleToCancelled() {
        var sessionState: CutWorkspaceTrackingSessionState? = CutWorkspaceTrackingSessionState(runStatus: .idle)

        let didResolve = CutWorkspaceTrackingLauncher.resolveCancelledBeforeRunIfNeeded(in: &sessionState)

        XCTAssertTrue(didResolve)
        XCTAssertEqual(sessionState?.runStatus, .cancelled(framesProcessed: 0, framesTotal: 0))
    }

    func testResolveCancelledBeforeRunIfNeededIgnoresNonIdleState() {
        var sessionState: CutWorkspaceTrackingSessionState? = CutWorkspaceTrackingSessionState(runStatus: .launching)

        let didResolve = CutWorkspaceTrackingLauncher.resolveCancelledBeforeRunIfNeeded(in: &sessionState)

        XCTAssertFalse(didResolve)
        XCTAssertEqual(sessionState?.runStatus, .launching)
    }

    func testMarkSkippedLaunchIdleIfNeededResetsOnlyLaunchingState() {
        var launching: CutWorkspaceTrackingSessionState? = CutWorkspaceTrackingSessionState(runStatus: .launching)
        var running: CutWorkspaceTrackingSessionState? = CutWorkspaceTrackingSessionState(
            runStatus: .running(message: "Tracking", current: nil, total: nil)
        )

        XCTAssertTrue(CutWorkspaceTrackingLauncher.markSkippedLaunchIdleIfNeeded(in: &launching))
        XCTAssertFalse(CutWorkspaceTrackingLauncher.markSkippedLaunchIdleIfNeeded(in: &running))
        XCTAssertEqual(launching?.runStatus, .idle)
        XCTAssertEqual(running?.runStatus, .running(message: "Tracking", current: nil, total: nil))
    }

    func testCancelCurrentRunUsesSessionStateCancellationRules() {
        var running: CutWorkspaceTrackingSessionState? = CutWorkspaceTrackingSessionState(
            runStatus: .running(message: "Tracking", current: 1, total: 2)
        )
        var launching: CutWorkspaceTrackingSessionState? = CutWorkspaceTrackingSessionState(runStatus: .launching)
        var completed: CutWorkspaceTrackingSessionState? = CutWorkspaceTrackingSessionState(runStatus: .completed)

        CutWorkspaceTrackingLauncher.cancelCurrentRun(in: &running)
        CutWorkspaceTrackingLauncher.cancelCurrentRun(in: &launching)
        CutWorkspaceTrackingLauncher.cancelCurrentRun(in: &completed)

        XCTAssertEqual(running?.runStatus, .cancelling)
        XCTAssertEqual(launching?.runStatus, .idle)
        XCTAssertEqual(completed?.runStatus, .completed)
    }
}
