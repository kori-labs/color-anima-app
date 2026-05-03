import ColorAnimaAppWorkspaceApplication
import Foundation
import XCTest

// MARK: - Stub client

/// Stub conformance to RegionRewriteClientProtocol for testing.
private struct StubRegionRewriteClient: RegionRewriteClientProtocol {
    let rewrittenRegionCount: Int
    let preservedOverrideCount: Int
    let kernelExecuted: Bool

    func run(
        frames: [RegionRewriteCoordinatorFrameInput],
        applyRange: ClosedRange<Int>,
        pinnedFrameIDs: Set<UUID>,
        canvasWidth: Int,
        canvasHeight: Int
    ) -> RegionRewriteCoordinatorApplyReport {
        RegionRewriteCoordinatorApplyReport(
            rewrittenRegionCount: rewrittenRegionCount,
            preservedOverrideCount: preservedOverrideCount,
            kernelExecuted: kernelExecuted
        )
    }
}

private let unavailableClient = StubRegionRewriteClient(
    rewrittenRegionCount: 0,
    preservedOverrideCount: 0,
    kernelExecuted: false
)

private let executedClient = StubRegionRewriteClient(
    rewrittenRegionCount: 5,
    preservedOverrideCount: 2,
    kernelExecuted: true
)

// MARK: - Tests

final class RegionRewriteCoordinatorTests: XCTestCase {

    // MARK: - deriveWindow

    func testDeriveWindowWithNoSurroundingReferences() {
        let window = RegionRewriteCoordinator.deriveWindow(
            referenceFrameIndices: [2],
            newReferenceIndex: 2,
            cutStartIndex: 0,
            cutEndIndex: 9
        )
        XCTAssertEqual(window.lowerBound, 0)
        XCTAssertEqual(window.upperBound, 9)
    }

    func testDeriveWindowClampsToPreviousAndNextReference() {
        // References at 0, 4, 9 — new reference at 4
        let window = RegionRewriteCoordinator.deriveWindow(
            referenceFrameIndices: [0, 4, 9],
            newReferenceIndex: 4,
            cutStartIndex: 0,
            cutEndIndex: 9
        )
        XCTAssertEqual(window.lowerBound, 0)
        XCTAssertEqual(window.upperBound, 9)
    }

    func testDeriveWindowWithMiddleReference() {
        // References at 0, 5, 10 — new reference at 5, cut ends at 10
        let window = RegionRewriteCoordinator.deriveWindow(
            referenceFrameIndices: [0, 5, 10],
            newReferenceIndex: 5,
            cutStartIndex: 0,
            cutEndIndex: 10
        )
        // prev = 0, next = 10 → window 0...10
        XCTAssertEqual(window.lowerBound, 0)
        XCTAssertEqual(window.upperBound, 10)
    }

    func testDeriveWindowClampedToStartAndEnd() {
        let window = RegionRewriteCoordinator.deriveWindow(
            referenceFrameIndices: [3],
            newReferenceIndex: 3,
            cutStartIndex: 0,
            cutEndIndex: 7
        )
        XCTAssertLessThanOrEqual(window.lowerBound, 3)
        XCTAssertGreaterThanOrEqual(window.upperBound, 3)
    }

    func testDeriveWindowAlwaysContainsNewReferenceIndex() {
        for newRef in [0, 1, 5, 9] {
            let window = RegionRewriteCoordinator.deriveWindow(
                referenceFrameIndices: [newRef],
                newReferenceIndex: newRef,
                cutStartIndex: 0,
                cutEndIndex: 9
            )
            XCTAssertTrue(window.contains(newRef), "Window must contain newReferenceIndex \(newRef)")
        }
    }

    // MARK: - isWithinSynchronousThreshold

    func testThresholdSmallWindowIsWithin() {
        XCTAssertTrue(RegionRewriteCoordinator.isWithinSynchronousThreshold(window: 0 ... 7))
    }

    func testThresholdExactBoundaryIsWithin() {
        let threshold = RegionRewriteCoordinator.synchronousReferenceEditFrameThreshold
        let window = 0 ... (threshold - 1)
        XCTAssertTrue(RegionRewriteCoordinator.isWithinSynchronousThreshold(window: window))
    }

    func testThresholdLargeWindowExceeds() {
        XCTAssertFalse(RegionRewriteCoordinator.isWithinSynchronousThreshold(window: 0 ... 100))
    }

    // MARK: - run with unavailable client

    func testRunWithUnavailableClientReturnsZeroCountReport() {
        let frames = makeFrames(count: 5)
        let report = RegionRewriteCoordinator.run(
            frames: frames,
            window: 0 ... 4,
            pinnedFrameIDs: [],
            canvasWidth: 1920,
            canvasHeight: 1080,
            client: unavailableClient
        )
        XCTAssertFalse(report.kernelExecuted)
        XCTAssertEqual(report.rewrittenRegionCount, 0)
        XCTAssertEqual(report.preservedOverrideCount, 0)
    }

    func testRunWindowFrameIndicesAreCorrect() {
        let frames = makeFrames(count: 5)
        let report = RegionRewriteCoordinator.run(
            frames: frames,
            window: 1 ... 3,
            pinnedFrameIDs: [],
            canvasWidth: 1920,
            canvasHeight: 1080,
            client: unavailableClient
        )
        XCTAssertEqual(report.windowFrameIndices, [1, 2, 3])
    }

    func testRunWindowFrameIDsCountMatchesIndices() {
        let frames = makeFrames(count: 5)
        let report = RegionRewriteCoordinator.run(
            frames: frames,
            window: 0 ... 2,
            pinnedFrameIDs: [],
            canvasWidth: 1920,
            canvasHeight: 1080,
            client: unavailableClient
        )
        XCTAssertEqual(report.windowFrameIDs.count, report.windowFrameIndices.count)
    }

    // MARK: - run with executed client

    func testRunWithExecutedClientReturnsCorrectCounts() {
        let frames = makeFrames(count: 5)
        let report = RegionRewriteCoordinator.run(
            frames: frames,
            window: 0 ... 4,
            pinnedFrameIDs: [],
            canvasWidth: 1920,
            canvasHeight: 1080,
            client: executedClient
        )
        XCTAssertTrue(report.kernelExecuted)
        XCTAssertEqual(report.rewrittenRegionCount, 5)
        XCTAssertEqual(report.preservedOverrideCount, 2)
    }

    // MARK: - feedbackMessage

    func testFeedbackMessageForUnavailableReport() {
        let report = RegionRewriteReport(
            rewrittenRegionCount: 0,
            preservedOverrideCount: 0,
            windowFrameIndices: [0, 1, 2],
            windowFrameIDs: [],
            kernelExecuted: false
        )
        let msg = RegionRewriteCoordinator.feedbackMessage(for: report)
        XCTAssertFalse(msg.isEmpty)
        XCTAssertTrue(msg.contains("not yet available") || msg.contains("not available"),
                      "Expected unavailability in message: \(msg)")
    }

    func testFeedbackMessageForExecutedReport() {
        let report = RegionRewriteReport(
            rewrittenRegionCount: 7,
            preservedOverrideCount: 2,
            windowFrameIndices: [0, 1, 2],
            windowFrameIDs: [],
            kernelExecuted: true
        )
        let msg = RegionRewriteCoordinator.feedbackMessage(for: report)
        XCTAssertTrue(msg.contains("3"), "Expected frame count 3 in message: \(msg)")
        XCTAssertTrue(msg.contains("7"), "Expected rewritten count 7 in message: \(msg)")
        XCTAssertTrue(msg.contains("2"), "Expected preserved count 2 in message: \(msg)")
    }

    // MARK: - RegionRewriteReport Hashable / Equatable

    func testReportEquality() {
        let a = RegionRewriteReport(
            rewrittenRegionCount: 3,
            preservedOverrideCount: 1,
            windowFrameIndices: [0, 1, 2],
            windowFrameIDs: [],
            kernelExecuted: false
        )
        let b = RegionRewriteReport(
            rewrittenRegionCount: 3,
            preservedOverrideCount: 1,
            windowFrameIndices: [0, 1, 2],
            windowFrameIDs: [],
            kernelExecuted: false
        )
        XCTAssertEqual(a, b)
    }

    // MARK: - Helpers

    private func makeFrames(count: Int) -> [RegionRewriteFrameDescriptor] {
        (0 ..< count).map { index in
            RegionRewriteFrameDescriptor(
                frameID: UUID(),
                orderIndex: index,
                isKeyFrame: index == 0
            )
        }
    }
}
