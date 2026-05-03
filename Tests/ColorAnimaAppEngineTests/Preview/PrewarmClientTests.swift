import ColorAnimaAppEngine
import Foundation
import XCTest

final class PrewarmClientTests: XCTestCase {

    // MARK: - Availability

    func testClientIsUnavailableWhileKernelFunctionNotExposed() {
        let client = PrewarmClient()
        XCTAssertFalse(client.isAvailable)
    }

    // MARK: - run returns zero-count report when unavailable

    func testRunReturnsZeroCountReportWhenUnavailable() {
        let client = PrewarmClient()
        let request = makeRequest(frameCount: 0, priority: .high)
        let report = client.run(request: request)
        XCTAssertEqual(report.computedFrameCount, 0)
        XCTAssertFalse(report.kernelExecuted)
    }

    func testRunWithNonEmptyFramesReturnsUnavailableReport() {
        let client = PrewarmClient()
        let request = makeRequest(frameCount: 5, priority: .low)
        let report = client.run(request: request)
        XCTAssertFalse(report.kernelExecuted)
        XCTAssertEqual(report.computedFrameCount, 0)
    }

    // MARK: - All priority tiers reach the bridge

    func testAllPriorityTiersReturnUnavailableReport() {
        let client = PrewarmClient()
        for tier in [PrewarmClientPriority.high, .medium, .low] {
            let request = makeRequest(frameCount: 2, priority: tier)
            let report = client.run(request: request)
            XCTAssertFalse(report.kernelExecuted, "Expected unavailable for tier \(tier)")
        }
    }

    // MARK: - feedbackMessage

    func testFeedbackMessageForUnavailableReport() {
        let client = PrewarmClient()
        let report = PrewarmApplyReport(computedFrameCount: 0, kernelExecuted: false)
        let message = client.feedbackMessage(for: report)
        XCTAssertFalse(message.isEmpty)
        XCTAssertTrue(
            message.contains("not available"),
            "Expected unavailability message, got: \(message)"
        )
    }

    func testFeedbackMessageForExecutedReport() {
        let client = PrewarmClient()
        let report = PrewarmApplyReport(computedFrameCount: 7, kernelExecuted: true)
        let message = client.feedbackMessage(for: report)
        XCTAssertTrue(message.contains("7"), "Expected frame count in message, got: \(message)")
    }

    // MARK: - DTO equality

    func testApplyReportEquality() {
        let a = PrewarmApplyReport(computedFrameCount: 3, kernelExecuted: false)
        let b = PrewarmApplyReport(computedFrameCount: 3, kernelExecuted: false)
        XCTAssertEqual(a, b)
    }

    func testClientRequestEquality() {
        let req1 = makeRequest(frameCount: 3, priority: .medium)
        let req2 = makeRequest(frameCount: 3, priority: .medium, seed: req1.frames.map(\.frameID))
        XCTAssertEqual(req1, req2)
    }

    // MARK: - Helpers

    private func makeRequest(
        frameCount: Int,
        priority: PrewarmClientPriority,
        seed: [UUID]? = nil
    ) -> PrewarmClientRequest {
        let ids = seed ?? (0 ..< frameCount).map { _ in UUID() }
        let frames = ids.enumerated().map { index, id in
            PrewarmClientFrameInput(frameID: id, orderIndex: index)
        }
        return PrewarmClientRequest(
            frames: frames,
            canvasWidth: 1920,
            canvasHeight: 1080,
            priorityTier: priority
        )
    }
}
