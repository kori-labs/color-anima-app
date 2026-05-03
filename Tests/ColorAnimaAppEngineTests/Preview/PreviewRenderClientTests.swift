import ColorAnimaAppEngine
import Foundation
import XCTest

final class PreviewRenderClientTests: XCTestCase {

    // MARK: - Availability

    func testClientIsUnavailableWhileKernelFunctionNotExposed() {
        let client = PreviewRenderClient()
        XCTAssertFalse(client.isAvailable)
    }

    // MARK: - run returns zero-count report when unavailable

    func testRunReturnsZeroCountReportWhenUnavailable() {
        let client = PreviewRenderClient()
        let request = makeRequest(frameCount: 0)
        let report = client.run(request: request)
        XCTAssertEqual(report.computedFrameCount, 0)
        XCTAssertFalse(report.kernelExecuted)
    }

    func testRunWithNonEmptyFramesReturnsUnavailableReport() {
        let client = PreviewRenderClient()
        let request = makeRequest(frameCount: 5)
        let report = client.run(request: request)
        XCTAssertFalse(report.kernelExecuted)
        XCTAssertEqual(report.computedFrameCount, 0)
    }

    // MARK: - feedbackMessage

    func testFeedbackMessageForUnavailableReport() {
        let client = PreviewRenderClient()
        let report = PreviewRenderReport(computedFrameCount: 0, kernelExecuted: false)
        let message = client.feedbackMessage(for: report)
        XCTAssertFalse(message.isEmpty)
        XCTAssertTrue(
            message.contains("not available"),
            "Expected unavailability message, got: \(message)"
        )
    }

    func testFeedbackMessageForExecutedReport() {
        let client = PreviewRenderClient()
        let report = PreviewRenderReport(computedFrameCount: 4, kernelExecuted: true)
        let message = client.feedbackMessage(for: report)
        XCTAssertTrue(message.contains("4"), "Expected frame count in message, got: \(message)")
    }

    // MARK: - DTO equality

    func testRenderReportEquality() {
        let a = PreviewRenderReport(computedFrameCount: 3, kernelExecuted: false)
        let b = PreviewRenderReport(computedFrameCount: 3, kernelExecuted: false)
        XCTAssertEqual(a, b)
    }

    func testClientRequestEquality() {
        let req1 = makeRequest(frameCount: 3)
        let req2 = makeRequest(frameCount: 3, seed: req1.frames.map(\.frameID))
        XCTAssertEqual(req1, req2)
    }

    // MARK: - Helpers

    private func makeRequest(
        frameCount: Int,
        seed: [UUID]? = nil
    ) -> PreviewRenderClientRequest {
        let ids = seed ?? (0 ..< frameCount).map { _ in UUID() }
        let frames = ids.enumerated().map { index, id in
            PreviewRenderClientFrameInput(
                frameID: id,
                orderIndex: index,
                hasComputedOverlay: index == 0
            )
        }
        return PreviewRenderClientRequest(
            canvasWidth: 1920,
            canvasHeight: 1080,
            frames: frames,
            selectedFrameID: ids.first
        )
    }
}
