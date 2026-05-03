import ColorAnimaAppEngine
import Foundation
import XCTest

final class TrackingClientTests: XCTestCase {

    // MARK: - Availability

    func testClientIsUnavailableWhileKernelFunctionNotExposed() {
        let client = TrackingClient()
        XCTAssertFalse(client.isAvailable)
    }

    // MARK: - run returns zero-count report when unavailable

    func testRunReturnsZeroCountReportWhenUnavailable() {
        let client = TrackingClient()
        let request = makeRequest(frameCount: 0, referenceIndices: [])
        let report = client.run(request: request)
        XCTAssertEqual(report.resolvedCorrespondenceCount, 0)
        XCTAssertEqual(report.processedFrameCount, 0)
        XCTAssertFalse(report.kernelExecuted)
    }

    func testRunWithNonEmptyFramesReturnsUnavailableReport() {
        let client = TrackingClient()
        let request = makeRequest(frameCount: 5, referenceIndices: [0])
        let report = client.run(request: request)
        XCTAssertFalse(report.kernelExecuted)
        XCTAssertEqual(report.resolvedCorrespondenceCount, 0)
    }

    // MARK: - feedbackMessage

    func testFeedbackMessageForUnavailableReport() {
        let client = TrackingClient()
        let report = TrackingApplyReport(
            resolvedCorrespondenceCount: 0,
            processedFrameCount: 0,
            kernelExecuted: false
        )
        let message = client.feedbackMessage(for: report)
        XCTAssertFalse(message.isEmpty)
        XCTAssertTrue(message.contains("not available"), "Expected unavailability message, got: \(message)")
    }

    func testFeedbackMessageForExecutedReport() {
        let client = TrackingClient()
        let report = TrackingApplyReport(
            resolvedCorrespondenceCount: 12,
            processedFrameCount: 4,
            kernelExecuted: true
        )
        let message = client.feedbackMessage(for: report)
        XCTAssertTrue(message.contains("4"), "Expected frame count in message, got: \(message)")
        XCTAssertTrue(message.contains("12"), "Expected resolved count in message, got: \(message)")
    }

    // MARK: - DTO equality

    func testApplyReportEquality() {
        let a = TrackingApplyReport(
            resolvedCorrespondenceCount: 3,
            processedFrameCount: 2,
            kernelExecuted: false
        )
        let b = TrackingApplyReport(
            resolvedCorrespondenceCount: 3,
            processedFrameCount: 2,
            kernelExecuted: false
        )
        XCTAssertEqual(a, b)
    }

    func testClientRequestEquality() {
        let req1 = makeRequest(frameCount: 3, referenceIndices: [0])
        let req2 = makeRequest(frameCount: 3, referenceIndices: [0], seed: req1.frames.map(\.frameID))
        XCTAssertEqual(req1, req2)
    }

    // MARK: - Helpers

    private func makeRequest(
        frameCount: Int,
        referenceIndices: [Int],
        seed: [UUID]? = nil
    ) -> TrackingClientRequest {
        let ids = seed ?? (0 ..< frameCount).map { _ in UUID() }
        let frames = ids.enumerated().map { index, id in
            TrackingClientFrameInput(
                frameID: id,
                orderIndex: index,
                isKeyFrame: referenceIndices.contains(index)
            )
        }
        let referenceIDs = Set(ids.enumerated().filter { referenceIndices.contains($0.offset) }.map(\.element))
        return TrackingClientRequest(
            frames: frames,
            keyFrameIDs: referenceIDs,
            canvasWidth: 1920,
            canvasHeight: 1080
        )
    }
}
