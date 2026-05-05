import ColorAnimaAppEngine
import Foundation
import XCTest

final class ExtractionClientTests: XCTestCase {

    // MARK: - Availability

    func testClientAvailabilityReflectsKernelTarget() {
        let client = ExtractionClient()
        XCTAssertEqual(client.isAvailable, kernelTargetRequested)
    }

    // MARK: - run returns zero-count report when unavailable

    func testRunReturnsZeroCountReportWhenUnavailable() {
        let client = ExtractionClient()
        let request = makeRequest(frameCount: 0)
        let report = client.run(request: request)
        XCTAssertEqual(report.totalRegionCount, 0)
        XCTAssertEqual(report.totalAdditionalRegionCount, 0)
        XCTAssertFalse(report.kernelExecuted)
        XCTAssertTrue(report.frameReports.isEmpty)
    }

    func testRunWithNonEmptyFramesUsesKernelWhenAvailable() {
        let client = ExtractionClient()
        let request = makeRequest(frameCount: 6)
        let report = client.run(request: request)
        XCTAssertEqual(report.kernelExecuted, client.isAvailable)
        XCTAssertEqual(report.totalRegionCount, 0)
        XCTAssertEqual(report.frameReports.count, client.isAvailable ? 6 : 0)
    }

    // MARK: - feedbackMessage

    func testFeedbackMessageForUnavailableReport() {
        let client = ExtractionClient()
        let report = ExtractionApplyReport(
            frameReports: [],
            totalRegionCount: 0,
            totalAdditionalRegionCount: 0,
            kernelExecuted: false
        )
        let message = client.feedbackMessage(for: report)
        XCTAssertFalse(message.isEmpty)
        XCTAssertTrue(message.contains("not available"), "Expected unavailability message, got: \(message)")
    }

    func testFeedbackMessageForExecutedReport() {
        let client = ExtractionClient()
        let id = UUID()
        let report = ExtractionApplyReport(
            frameReports: [
                ExtractionFrameReport(frameID: id, regionCount: 0, additionalRegionCount: 0)
            ],
            totalRegionCount: 12,
            totalAdditionalRegionCount: 3,
            kernelExecuted: true
        )
        let message = client.feedbackMessage(for: report)
        XCTAssertTrue(message.contains("12"), "Expected total region count in message, got: \(message)")
        XCTAssertTrue(message.contains("1"), "Expected frame count in message, got: \(message)")
    }

    // MARK: - DTO equality

    func testApplyReportEquality() {
        let id = UUID()
        let frameReport = ExtractionFrameReport(frameID: id, regionCount: 0, additionalRegionCount: 0)
        let a = ExtractionApplyReport(
            frameReports: [frameReport],
            totalRegionCount: 5,
            totalAdditionalRegionCount: 2,
            kernelExecuted: false
        )
        let b = ExtractionApplyReport(
            frameReports: [frameReport],
            totalRegionCount: 5,
            totalAdditionalRegionCount: 2,
            kernelExecuted: false
        )
        XCTAssertEqual(a, b)
    }

    func testClientRequestEquality() {
        let req1 = makeRequest(frameCount: 4)
        let req2 = makeRequest(frameCount: 4, seed: req1.frames.map(\.frameID))
        XCTAssertEqual(req1, req2)
    }

    func testFrameReportEquality() {
        let id = UUID()
        let a = ExtractionFrameReport(frameID: id, regionCount: 0, additionalRegionCount: 0)
        let b = ExtractionFrameReport(frameID: id, regionCount: 0, additionalRegionCount: 0)
        XCTAssertEqual(a, b)
    }

    // MARK: - Helpers

    private var kernelTargetRequested: Bool {
        let environment = ProcessInfo.processInfo.environment
        return environment["COLOR_ANIMA_KERNEL_PATH"] != nil ||
            environment["COLOR_ANIMA_KERNEL_URL"] != nil
    }

    private func makeRequest(
        frameCount: Int,
        seed: [UUID]? = nil
    ) -> ExtractionClientRequest {
        let ids = seed ?? (0 ..< frameCount).map { _ in UUID() }
        let frames = ids.enumerated().map { index, id in
            ExtractionClientFrameInput(frameID: id, orderIndex: index)
        }
        return ExtractionClientRequest(
            frames: frames,
            canvasWidth: 1024,
            canvasHeight: 1024
        )
    }
}
