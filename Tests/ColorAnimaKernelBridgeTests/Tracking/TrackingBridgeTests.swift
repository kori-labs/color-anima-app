import ColorAnimaKernelBridge
import Foundation
import XCTest

final class TrackingBridgeTests: XCTestCase {

    // MARK: - TrackingBridge availability

    func testBridgeAvailabilityReflectsKernelSurface() {
        let bridge = TrackingBridge()
        XCTAssertFalse(bridge.isTrackingAvailable)
    }

    // MARK: - Result path: .unavailable fallback

    func testRunReturnsUnavailableWhenKernelFunctionNotExposed() {
        let bridge = TrackingBridge()
        let request = TrackingRequest(
            frames: [],
            keyFrameIDs: [],
            canvasWidth: 1920,
            canvasHeight: 1080
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
        let bridge = TrackingBridge()
        let frameIDs = (0 ..< 5).map { _ in UUID() }
        let frames = frameIDs.enumerated().map { index, id in
            TrackingFrameInput(
                frameID: id,
                orderIndex: index,
                isKeyFrame: index == 0
            )
        }
        let request = TrackingRequest(
            frames: frames,
            keyFrameIDs: [frameIDs[0]],
            canvasWidth: 1920,
            canvasHeight: 1080
        )
        let result = bridge.run(request: request)
        guard case .failure(let error) = result else {
            XCTFail("Expected .failure(.unavailable)")
            return
        }
        XCTAssertEqual(error, .unavailable)
    }

    // MARK: - DTO construction

    func testTrackingRequestEquality() {
        let id = UUID()
        let frame = TrackingFrameInput(frameID: id, orderIndex: 0, isKeyFrame: true)
        let req1 = TrackingRequest(
            frames: [frame],
            keyFrameIDs: [id],
            canvasWidth: 1280,
            canvasHeight: 720
        )
        let req2 = TrackingRequest(
            frames: [frame],
            keyFrameIDs: [id],
            canvasWidth: 1280,
            canvasHeight: 720
        )
        XCTAssertEqual(req1, req2)
    }

    func testTrackingResultEquality() {
        let id = UUID()
        let frameResult = TrackingFrameResult(frameID: id, resolvedCorrespondenceCount: 4)
        let result1 = TrackingResult(
            frameResults: [id: frameResult],
            totalResolvedCount: 4,
            completed: true
        )
        let result2 = TrackingResult(
            frameResults: [id: frameResult],
            totalResolvedCount: 4,
            completed: true
        )
        XCTAssertEqual(result1, result2)
    }

    func testTrackingHandleEquality() {
        let handle1 = TrackingHandle(pointer: nil)
        let handle2 = TrackingHandle(pointer: nil)
        XCTAssertEqual(handle1, handle2)
    }

    func testFrameInputEquality() {
        let id = UUID()
        let a = TrackingFrameInput(frameID: id, orderIndex: 2, isKeyFrame: false)
        let b = TrackingFrameInput(frameID: id, orderIndex: 2, isKeyFrame: false)
        XCTAssertEqual(a, b)
    }
}
