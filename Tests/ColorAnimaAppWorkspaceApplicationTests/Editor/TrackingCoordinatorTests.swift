import ColorAnimaAppWorkspaceApplication
import Foundation
import XCTest

// MARK: - Stub client

/// Stub conformance to TrackingClientProtocol for testing.
private struct StubTrackingClient: TrackingClientProtocol {
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

private let unavailableClient = StubTrackingClient(
    resolvedCorrespondenceCount: 0,
    processedFrameCount: 0,
    kernelExecuted: false
)

private let executedClient = StubTrackingClient(
    resolvedCorrespondenceCount: 8,
    processedFrameCount: 4,
    kernelExecuted: true
)

// MARK: - Tests

final class TrackingCoordinatorTests: XCTestCase {

    // MARK: - run with unavailable client

    func testRunWithUnavailableClientReturnsZeroCountReport() {
        let frames = makeFrames(count: 5, referenceIndex: 0)
        let referenceIDs = Set(frames.filter(\.isKeyFrame).map(\.frameID))
        let report = TrackingCoordinator.run(
            frames: frames,
            keyFrameIDs: referenceIDs,
            canvasWidth: 1920,
            canvasHeight: 1080,
            client: unavailableClient
        )
        XCTAssertFalse(report.kernelExecuted)
        XCTAssertEqual(report.resolvedCorrespondenceCount, 0)
        XCTAssertEqual(report.processedFrameCount, 0)
    }

    func testRunProcessedFrameIDsMatchInput() {
        let frames = makeFrames(count: 5, referenceIndex: 0)
        let referenceIDs = Set(frames.filter(\.isKeyFrame).map(\.frameID))
        let report = TrackingCoordinator.run(
            frames: frames,
            keyFrameIDs: referenceIDs,
            canvasWidth: 1920,
            canvasHeight: 1080,
            client: unavailableClient
        )
        XCTAssertEqual(Set(report.processedFrameIDs), Set(frames.map(\.frameID)))
    }

    func testRunProcessedFrameIDsCountMatchesInput() {
        let frames = makeFrames(count: 3, referenceIndex: 0)
        let referenceIDs = Set(frames.filter(\.isKeyFrame).map(\.frameID))
        let report = TrackingCoordinator.run(
            frames: frames,
            keyFrameIDs: referenceIDs,
            canvasWidth: 1920,
            canvasHeight: 1080,
            client: unavailableClient
        )
        XCTAssertEqual(report.processedFrameIDs.count, frames.count)
    }

    // MARK: - run with executed client

    func testRunWithExecutedClientReturnsCorrectCounts() {
        let frames = makeFrames(count: 5, referenceIndex: 0)
        let referenceIDs = Set(frames.filter(\.isKeyFrame).map(\.frameID))
        let report = TrackingCoordinator.run(
            frames: frames,
            keyFrameIDs: referenceIDs,
            canvasWidth: 1920,
            canvasHeight: 1080,
            client: executedClient
        )
        XCTAssertTrue(report.kernelExecuted)
        XCTAssertEqual(report.resolvedCorrespondenceCount, 8)
        XCTAssertEqual(report.processedFrameCount, 4)
    }

    // MARK: - feedbackMessage

    func testFeedbackMessageForUnavailableReport() {
        let report = TrackingRunReport(
            resolvedCorrespondenceCount: 0,
            processedFrameCount: 3,
            processedFrameIDs: [],
            kernelExecuted: false
        )
        let msg = TrackingCoordinator.feedbackMessage(for: report)
        XCTAssertFalse(msg.isEmpty)
        XCTAssertTrue(
            msg.contains("not yet available") || msg.contains("not available"),
            "Expected unavailability in message: \(msg)"
        )
    }

    func testFeedbackMessageForExecutedReport() {
        let report = TrackingRunReport(
            resolvedCorrespondenceCount: 10,
            processedFrameCount: 5,
            processedFrameIDs: [],
            kernelExecuted: true
        )
        let msg = TrackingCoordinator.feedbackMessage(for: report)
        XCTAssertTrue(msg.contains("5"), "Expected frame count 5 in message: \(msg)")
        XCTAssertTrue(msg.contains("10"), "Expected resolved count 10 in message: \(msg)")
    }

    // MARK: - TrackingRunReport Hashable / Equatable

    func testReportEquality() {
        let a = TrackingRunReport(
            resolvedCorrespondenceCount: 3,
            processedFrameCount: 2,
            processedFrameIDs: [],
            kernelExecuted: false
        )
        let b = TrackingRunReport(
            resolvedCorrespondenceCount: 3,
            processedFrameCount: 2,
            processedFrameIDs: [],
            kernelExecuted: false
        )
        XCTAssertEqual(a, b)
    }

    // MARK: - Helpers

    private func makeFrames(count: Int, referenceIndex: Int) -> [TrackingFrameDescriptor] {
        (0 ..< count).map { index in
            TrackingFrameDescriptor(
                frameID: UUID(),
                orderIndex: index,
                isKeyFrame: index == referenceIndex
            )
        }
    }
}
