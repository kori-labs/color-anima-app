import ColorAnimaKernelBridge
import Foundation
import XCTest

final class PrewarmBridgeTests: XCTestCase {

    // MARK: - Availability

    func testBridgeAvailabilityReflectsKernelSurface() {
        let bridge = PrewarmBridge()
        XCTAssertFalse(bridge.isPrewarmAvailable)
    }

    // MARK: - Result path: .unavailable fallback

    func testRunReturnsUnavailableWhenKernelFunctionNotExposed() {
        let bridge = PrewarmBridge()
        let request = PrewarmRequest(
            frames: [],
            canvasWidth: 1920,
            canvasHeight: 1080,
            priorityTier: .high
        )
        let result = bridge.run(request: request)
        switch result {
        case .failure(let error):
            XCTAssertEqual(error, .unavailable)
        case .success:
            XCTFail("Expected .failure(.unavailable) while kernel C function is not exposed")
        }
    }

    func testRunReturnsUnavailableForNonEmptyRequest() {
        let bridge = PrewarmBridge()
        let frameIDs = (0 ..< 5).map { _ in UUID() }
        let frames = frameIDs.enumerated().map { index, id in
            PrewarmFrameInput(frameID: id, orderIndex: index)
        }
        let request = PrewarmRequest(
            frames: frames,
            canvasWidth: 1920,
            canvasHeight: 1080,
            priorityTier: .low
        )
        let result = bridge.run(request: request)
        guard case .failure(let error) = result else {
            XCTFail("Expected .failure(.unavailable)")
            return
        }
        XCTAssertEqual(error, .unavailable)
    }

    // MARK: - DTO construction

    func testPrewarmRequestEquality() {
        let id = UUID()
        let frame = PrewarmFrameInput(frameID: id, orderIndex: 0)
        let req1 = PrewarmRequest(
            frames: [frame],
            canvasWidth: 1280,
            canvasHeight: 720,
            priorityTier: .medium
        )
        let req2 = PrewarmRequest(
            frames: [frame],
            canvasWidth: 1280,
            canvasHeight: 720,
            priorityTier: .medium
        )
        XCTAssertEqual(req1, req2)
    }

    func testPrewarmHandleEquality() {
        let handle1 = PrewarmHandle(pointer: nil)
        let handle2 = PrewarmHandle(pointer: nil)
        XCTAssertEqual(handle1, handle2)
    }

    func testPrewarmFrameInputEquality() {
        let id = UUID()
        let a = PrewarmFrameInput(frameID: id, orderIndex: 3)
        let b = PrewarmFrameInput(frameID: id, orderIndex: 3)
        XCTAssertEqual(a, b)
    }

    func testPrewarmResultEquality() {
        let id = UUID()
        let frameResult = PrewarmFrameResult(frameID: id, previewStateComputed: true)
        let result1 = PrewarmResult(
            frameResults: [id: frameResult],
            computedFrameCount: 1,
            kernelExecuted: false
        )
        let result2 = PrewarmResult(
            frameResults: [id: frameResult],
            computedFrameCount: 1,
            kernelExecuted: false
        )
        XCTAssertEqual(result1, result2)
    }

    func testAllPriorityTiersAreDistinct() {
        XCTAssertNotEqual(PrewarmPriority.high, .medium)
        XCTAssertNotEqual(PrewarmPriority.medium, .low)
        XCTAssertNotEqual(PrewarmPriority.high, .low)
    }
}
