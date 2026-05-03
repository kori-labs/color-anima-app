import ColorAnimaKernelBridge
import Foundation
import XCTest

final class PreviewRenderBridgeTests: XCTestCase {

    // MARK: - Availability

    func testBridgeAvailabilityReflectsKernelSurface() {
        let bridge = PreviewRenderBridge()
        XCTAssertFalse(bridge.isPreviewRenderAvailable)
    }

    // MARK: - Result path: .unavailable fallback

    func testRunReturnsUnavailableWhenKernelFunctionNotExposed() {
        let bridge = PreviewRenderBridge()
        let request = PreviewRenderRequest(
            canvas: PreviewRenderCanvasDescriptor(width: 1920, height: 1080),
            frames: [],
            selectedFrameID: nil
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
        let bridge = PreviewRenderBridge()
        let frameIDs = (0 ..< 5).map { _ in UUID() }
        let frames = frameIDs.enumerated().map { index, id in
            PreviewRenderFrameInput(
                frameID: id,
                orderIndex: index,
                hasComputedOverlay: index == 0
            )
        }
        let selectedID = frameIDs[0]
        let request = PreviewRenderRequest(
            canvas: PreviewRenderCanvasDescriptor(width: 1920, height: 1080),
            frames: frames,
            selectedFrameID: selectedID
        )
        let result = bridge.run(request: request)
        guard case .failure(let error) = result else {
            XCTFail("Expected .failure(.unavailable)")
            return
        }
        XCTAssertEqual(error, .unavailable)
    }

    // MARK: - DTO construction

    func testPreviewRenderRequestEquality() {
        let id = UUID()
        let frame = PreviewRenderFrameInput(frameID: id, orderIndex: 0, hasComputedOverlay: false)
        let canvas = PreviewRenderCanvasDescriptor(width: 1280, height: 720)
        let req1 = PreviewRenderRequest(canvas: canvas, frames: [frame], selectedFrameID: id)
        let req2 = PreviewRenderRequest(canvas: canvas, frames: [frame], selectedFrameID: id)
        XCTAssertEqual(req1, req2)
    }

    func testPreviewRenderHandleEquality() {
        let handle1 = PreviewRenderHandle(pointer: nil)
        let handle2 = PreviewRenderHandle(pointer: nil)
        XCTAssertEqual(handle1, handle2)
    }

    func testPreviewRenderFrameInputEquality() {
        let id = UUID()
        let a = PreviewRenderFrameInput(frameID: id, orderIndex: 2, hasComputedOverlay: true)
        let b = PreviewRenderFrameInput(frameID: id, orderIndex: 2, hasComputedOverlay: true)
        XCTAssertEqual(a, b)
    }

    func testPreviewRenderCanvasDescriptorEquality() {
        let a = PreviewRenderCanvasDescriptor(width: 1920, height: 1080)
        let b = PreviewRenderCanvasDescriptor(width: 1920, height: 1080)
        XCTAssertEqual(a, b)
    }
}
