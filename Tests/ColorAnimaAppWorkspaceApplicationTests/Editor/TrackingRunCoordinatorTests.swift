import ColorAnimaAppWorkspaceApplication
import Foundation
import XCTest

// MARK: - Stub client

private struct StubTrackingRunClient: TrackingClientProtocol {
    let resolvedCorrespondenceCount: Int
    let processedFrameCount: Int
    let kernelExecuted: Bool

    func run(
        frames: [TrackingCoordinatorFrameInput],
        keyFrameIDs: Set<UUID>,
        canvasWidth: Int,
        canvasHeight: Int
    ) -> TrackingCoordinatorApplyReport {
        TrackingCoordinatorApplyReport(
            resolvedCorrespondenceCount: resolvedCorrespondenceCount,
            processedFrameCount: processedFrameCount,
            kernelExecuted: kernelExecuted
        )
    }
}

private let stubUnavailable = StubTrackingRunClient(
    resolvedCorrespondenceCount: 0,
    processedFrameCount: 0,
    kernelExecuted: false
)

private let stubExecuted = StubTrackingRunClient(
    resolvedCorrespondenceCount: 6,
    processedFrameCount: 3,
    kernelExecuted: true
)

// MARK: - Tests

final class TrackingRunCoordinatorTests: XCTestCase {

    // MARK: - canRun

    func testCanRunReturnsFalseForEmptyFrames() {
        let input = TrackingRunInput(
            frames: [],
            keyFrameIDs: [],
            canvasWidth: 1920,
            canvasHeight: 1080
        )
        let (canRun, reason) = TrackingRunCoordinator.canRun(input: input)
        XCTAssertFalse(canRun)
        XCTAssertNotNil(reason)
    }

    func testCanRunReturnsFalseWhenNoReferenceFrames() {
        let frames = makeFrames(count: 3, referenceIndex: nil)
        let input = TrackingRunInput(
            frames: frames,
            keyFrameIDs: [],
            canvasWidth: 1920,
            canvasHeight: 1080
        )
        let (canRun, reason) = TrackingRunCoordinator.canRun(input: input)
        XCTAssertFalse(canRun)
        XCTAssertNotNil(reason)
    }

    func testCanRunReturnsFalseWhenAllFramesAreReference() {
        let frames = makeFrames(count: 1, referenceIndex: 0)
        let referenceIDs = Set(frames.map(\.frameID))
        let input = TrackingRunInput(
            frames: frames,
            keyFrameIDs: referenceIDs,
            canvasWidth: 1920,
            canvasHeight: 1080
        )
        let (canRun, reason) = TrackingRunCoordinator.canRun(input: input)
        XCTAssertFalse(canRun)
        XCTAssertNotNil(reason)
    }

    func testCanRunReturnsTrueForValidInput() {
        let input = makeValidInput(frameCount: 3)
        let (canRun, reason) = TrackingRunCoordinator.canRun(input: input)
        XCTAssertTrue(canRun)
        XCTAssertNil(reason)
    }

    // MARK: - run transitions

    func testRunTransitionsToCompletedOnSuccess() {
        let input = makeValidInput(frameCount: 3)
        let state = TrackingRunState()
        let result = TrackingRunCoordinator.run(input: input, state: state, client: stubUnavailable)
        if case .completed = result.status {
            // pass
        } else {
            XCTFail("Expected .completed, got \(result.status)")
        }
    }

    func testRunTransitionsToFailedWhenCannotRun() {
        let input = TrackingRunInput(
            frames: [],
            keyFrameIDs: [],
            canvasWidth: 1920,
            canvasHeight: 1080
        )
        let state = TrackingRunState()
        let result = TrackingRunCoordinator.run(input: input, state: state, client: stubUnavailable)
        if case .failed = result.status {
            // pass
        } else {
            XCTFail("Expected .failed, got \(result.status)")
        }
    }

    func testRunIncrementsGeneration() {
        let input = makeValidInput(frameCount: 3)
        let state = TrackingRunState(generation: 0)
        let result = TrackingRunCoordinator.run(input: input, state: state, client: stubUnavailable)
        XCTAssertEqual(result.generation, 1)
    }

    func testRunWithExecutedClientProducesReport() {
        let input = makeValidInput(frameCount: 4)
        let state = TrackingRunState()
        let result = TrackingRunCoordinator.run(input: input, state: state, client: stubExecuted)
        guard case .completed(let report) = result.status else {
            XCTFail("Expected .completed")
            return
        }
        XCTAssertTrue(report.kernelExecuted)
        XCTAssertEqual(report.resolvedCorrespondenceCount, 6)
    }

    // MARK: - cancel

    func testCancelTransitionsRunningToCancelled() {
        var state = TrackingRunState()
        state.status = .running(message: "Running\u{2026}")
        let result = TrackingRunCoordinator.cancel(state: state)
        XCTAssertEqual(result.status, .cancelled)
    }

    func testCancelIsNoOpWhenNotRunning() {
        let state = TrackingRunState(status: .idle)
        let result = TrackingRunCoordinator.cancel(state: state)
        XCTAssertEqual(result.status, .idle)
    }

    // MARK: - sessionFeedback

    func testSessionFeedbackIsNilForIdleState() {
        let state = TrackingRunState(status: .idle)
        XCTAssertNil(TrackingRunCoordinator.sessionFeedback(for: state))
    }

    func testSessionFeedbackIsNonNilForCompletedState() {
        let report = TrackingRunReport(
            resolvedCorrespondenceCount: 3,
            processedFrameCount: 2,
            processedFrameIDs: [],
            kernelExecuted: false
        )
        var state = TrackingRunState()
        state.status = .completed(report: report)
        let feedback = TrackingRunCoordinator.sessionFeedback(for: state)
        XCTAssertNotNil(feedback)
        XCTAssertFalse(feedback!.isEmpty)
    }

    // MARK: - TrackingRunState equality

    func testRunStateEquality() {
        let a = TrackingRunState(status: .idle, generation: 0)
        let b = TrackingRunState(status: .idle, generation: 0)
        XCTAssertEqual(a, b)
    }

    // MARK: - Helpers

    private func makeFrames(count: Int, referenceIndex: Int?) -> [TrackingFrameDescriptor] {
        (0 ..< count).map { index in
            TrackingFrameDescriptor(
                frameID: UUID(),
                orderIndex: index,
                isKeyFrame: index == referenceIndex
            )
        }
    }

    private func makeValidInput(frameCount: Int) -> TrackingRunInput {
        let frames = makeFrames(count: frameCount, referenceIndex: 0)
        let referenceIDs = Set(frames.filter(\.isKeyFrame).map(\.frameID))
        return TrackingRunInput(
            frames: frames,
            keyFrameIDs: referenceIDs,
            canvasWidth: 1920,
            canvasHeight: 1080
        )
    }
}
