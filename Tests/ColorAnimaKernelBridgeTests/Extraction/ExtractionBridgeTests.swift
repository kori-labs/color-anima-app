import ColorAnimaKernelBridge
import Foundation
import XCTest

final class ExtractionBridgeTests: XCTestCase {

    // MARK: - ExtractionBridge availability

    func testBridgeAvailabilityReflectsKernelSurface() {
        let bridge = ExtractionBridge()
        XCTAssertEqual(bridge.isExtractionAvailable, KernelBridge().status.isLinked)
    }

    // MARK: - Result paths

    func testRunReturnsUnavailableForEmptyRequest() {
        let bridge = ExtractionBridge()
        let request = ExtractionRequest(
            frames: [],
            canvasWidth: 1920,
            canvasHeight: 1080
        )
        let result = bridge.run(request: request)
        switch result {
        case .failure(let error):
            XCTAssertEqual(error, .unavailable)
        case .success:
            XCTFail("Expected .failure(.unavailable) for empty request")
        }
    }

    func testRunUsesKernelWhenLinkedForNonEmptyRequest() {
        let bridge = ExtractionBridge()
        let frameIDs = (0 ..< 6).map { _ in UUID() }
        let frames = frameIDs.enumerated().map { index, id in
            ExtractionFrameInput(frameID: id, orderIndex: index)
        }
        let request = ExtractionRequest(
            frames: frames,
            canvasWidth: 1024,
            canvasHeight: 1024
        )
        let result = bridge.run(request: request)
        if bridge.isExtractionAvailable {
            guard case .success(let output) = result else {
                XCTFail("Expected success when kernel is linked")
                return
            }
            XCTAssertEqual(output.frameResults.count, frames.count)
            XCTAssertEqual(output.totalRegionCount, 0)
            XCTAssertEqual(output.totalAdditionalRegionCount, 0)
        } else {
            guard case .failure(let error) = result else {
                XCTFail("Expected .failure(.unavailable)")
                return
            }
            XCTAssertEqual(error, .unavailable)
        }
    }

    // MARK: - DTO construction

    func testExtractionRequestEquality() {
        let id = UUID()
        let frame = ExtractionFrameInput(frameID: id, orderIndex: 0)
        let req1 = ExtractionRequest(frames: [frame], canvasWidth: 1280, canvasHeight: 720)
        let req2 = ExtractionRequest(frames: [frame], canvasWidth: 1280, canvasHeight: 720)
        XCTAssertEqual(req1, req2)
    }

    func testExtractionResultEquality() {
        let id = UUID()
        let frameResult = ExtractionFrameResult(frameID: id, regionCount: 0, additionalRegionCount: 0)
        let result1 = ExtractionResult(
            frameResults: [id: frameResult],
            totalRegionCount: 5,
            totalAdditionalRegionCount: 3
        )
        let result2 = ExtractionResult(
            frameResults: [id: frameResult],
            totalRegionCount: 5,
            totalAdditionalRegionCount: 3
        )
        XCTAssertEqual(result1, result2)
    }

    func testExtractionFrameInputEquality() {
        let id = UUID()
        let a = ExtractionFrameInput(frameID: id, orderIndex: 2)
        let b = ExtractionFrameInput(frameID: id, orderIndex: 2)
        XCTAssertEqual(a, b)
    }

    func testExtractionFrameResultEquality() {
        let id = UUID()
        let a = ExtractionFrameResult(frameID: id, regionCount: 10, additionalRegionCount: 4)
        let b = ExtractionFrameResult(frameID: id, regionCount: 10, additionalRegionCount: 4)
        XCTAssertEqual(a, b)
    }
}
