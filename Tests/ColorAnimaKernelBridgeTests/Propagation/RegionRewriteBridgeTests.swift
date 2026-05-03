import ColorAnimaKernelBridge
import Foundation
import XCTest

final class RegionRewriteBridgeTests: XCTestCase {

    // MARK: - RegionRewriteBridge availability

    func testBridgeAvailabilityReflectsKernelSurface() {
        let bridge = RegionRewriteBridge()
        // The region rewrite C function is not yet exposed in the kernel
        // surface (stub state). Availability must be false until the core repo
        XCTAssertFalse(bridge.isRegionRewriteAvailable)
    }

    // MARK: - Result path: .unavailable fallback

    func testRunReturnsUnavailableWhenKernelFunctionNotExposed() {
        let bridge = RegionRewriteBridge()
        let request = RegionRewriteRequest(
            frames: [],
            applyRange: 0 ... 0,
            pinnedFrameIDs: [],
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
        let bridge = RegionRewriteBridge()
        let frameIDs = (0 ..< 5).map { _ in UUID() }
        let frames = frameIDs.enumerated().map { index, id in
            RegionRewriteFrameInput(
                frameID: id,
                orderIndex: index,
                isKeyFrame: index == 0
            )
        }
        let request = RegionRewriteRequest(
            frames: frames,
            applyRange: 0 ... 4,
            pinnedFrameIDs: [frameIDs[2]],
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

    func testRegionRewriteRequestEquality() {
        let id = UUID()
        let frame = RegionRewriteFrameInput(frameID: id, orderIndex: 0, isKeyFrame: true)
        let req1 = RegionRewriteRequest(
            frames: [frame],
            applyRange: 0 ... 3,
            pinnedFrameIDs: [id],
            canvasWidth: 1280,
            canvasHeight: 720
        )
        let req2 = RegionRewriteRequest(
            frames: [frame],
            applyRange: 0 ... 3,
            pinnedFrameIDs: [id],
            canvasWidth: 1280,
            canvasHeight: 720
        )
        XCTAssertEqual(req1, req2)
    }

    func testRegionRewriteResultEquality() {
        let id = UUID()
        let frameResult = RegionRewriteFrameResult(frameID: id, updatedRegionCount: 3)
        let result1 = RegionRewriteResult(
            frameResults: [id: frameResult],
            totalRewrittenCount: 3,
            totalPreservedOverrideCount: 1
        )
        let result2 = RegionRewriteResult(
            frameResults: [id: frameResult],
            totalRewrittenCount: 3,
            totalPreservedOverrideCount: 1
        )
        XCTAssertEqual(result1, result2)
    }

    func testRegionRewriteHandleEquality() {
        let handle1 = RegionRewriteHandle(pointer: nil)
        let handle2 = RegionRewriteHandle(pointer: nil)
        XCTAssertEqual(handle1, handle2)
    }

    func testFrameInputEquality() {
        let id = UUID()
        let a = RegionRewriteFrameInput(frameID: id, orderIndex: 2, isKeyFrame: false)
        let b = RegionRewriteFrameInput(frameID: id, orderIndex: 2, isKeyFrame: false)
        XCTAssertEqual(a, b)
    }
}
