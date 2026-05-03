import ColorAnimaAppEngine
import Foundation
import XCTest

final class RegionRewriteClientTests: XCTestCase {

    // MARK: - Availability

    func testClientIsUnavailableWhileKernelFunctionNotExposed() {
        let client = RegionRewriteClient()
        XCTAssertFalse(client.isAvailable)
    }

    // MARK: - run returns zero-count report when unavailable

    func testRunReturnsZeroCountReportWhenUnavailable() {
        let client = RegionRewriteClient()
        let request = makeRequest(frameCount: 0, applyRange: 0 ... 0)
        let report = client.run(request: request)
        XCTAssertEqual(report.rewrittenRegionCount, 0)
        XCTAssertEqual(report.preservedOverrideCount, 0)
        XCTAssertFalse(report.kernelExecuted)
    }

    func testRunWithNonEmptyFramesReturnsUnavailableReport() {
        let client = RegionRewriteClient()
        let request = makeRequest(frameCount: 5, applyRange: 0 ... 4)
        let report = client.run(request: request)
        XCTAssertFalse(report.kernelExecuted)
        XCTAssertEqual(report.rewrittenRegionCount, 0)
    }

    // MARK: - feedbackMessage

    func testFeedbackMessageForUnavailableReport() {
        let client = RegionRewriteClient()
        let report = RegionRewriteApplyReport(
            rewrittenRegionCount: 0,
            preservedOverrideCount: 0,
            kernelExecuted: false
        )
        let message = client.feedbackMessage(for: report)
        XCTAssertFalse(message.isEmpty)
        XCTAssertTrue(message.contains("not available"), "Expected unavailability message, got: \(message)")
    }

    func testFeedbackMessageForExecutedReport() {
        let client = RegionRewriteClient()
        let report = RegionRewriteApplyReport(
            rewrittenRegionCount: 7,
            preservedOverrideCount: 2,
            kernelExecuted: true
        )
        let message = client.feedbackMessage(for: report)
        XCTAssertTrue(message.contains("7"), "Expected rewritten count in message, got: \(message)")
        XCTAssertTrue(message.contains("2"), "Expected preserved count in message, got: \(message)")
    }

    // MARK: - DTO equality

    func testApplyReportEquality() {
        let a = RegionRewriteApplyReport(
            rewrittenRegionCount: 3,
            preservedOverrideCount: 1,
            kernelExecuted: false
        )
        let b = RegionRewriteApplyReport(
            rewrittenRegionCount: 3,
            preservedOverrideCount: 1,
            kernelExecuted: false
        )
        XCTAssertEqual(a, b)
    }

    func testClientRequestEquality() {
        let req1 = makeRequest(frameCount: 3, applyRange: 0 ... 2)
        let req2 = makeRequest(frameCount: 3, applyRange: 0 ... 2, seed: req1.frames.map(\.frameID))
        XCTAssertEqual(req1, req2)
    }

    // MARK: - Helpers

    private func makeRequest(
        frameCount: Int,
        applyRange: ClosedRange<Int>,
        seed: [UUID]? = nil
    ) -> RegionRewriteClientRequest {
        let ids = seed ?? (0 ..< frameCount).map { _ in UUID() }
        let frames = ids.enumerated().map { index, id in
            RegionRewriteClientFrameInput(
                frameID: id,
                orderIndex: index,
                isKeyFrame: index == 0
            )
        }
        return RegionRewriteClientRequest(
            frames: frames,
            applyRange: applyRange,
            pinnedFrameIDs: [],
            canvasWidth: 1920,
            canvasHeight: 1080
        )
    }
}
