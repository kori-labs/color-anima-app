import CoreGraphics
import XCTest
@testable import ColorAnimaAppWorkspaceCutEditor

final class CanvasPreviewZoomControlsTests: XCTestCase {
    func testZoomControlsStateDisablesZoomOutAtMinimumAndResetAtIdentity() {
        let state = CanvasPreviewZoomControlsState(
            effectiveZoomScale: 1,
            minimumZoomScale: 1,
            maximumZoomScale: 4,
            committedOffset: .zero
        )

        XCTAssertFalse(state.canZoomOut)
        XCTAssertTrue(state.canZoomIn)
        XCTAssertFalse(state.canReset)
        XCTAssertEqual(state.zoomPercentage, 100)
    }

    func testZoomControlsStateDisablesZoomInAtMaximumAndAllowsResetAfterZooming() {
        let state = CanvasPreviewZoomControlsState(
            effectiveZoomScale: 4,
            minimumZoomScale: 1,
            maximumZoomScale: 4,
            committedOffset: CGSize(width: 12, height: -6)
        )

        XCTAssertTrue(state.canZoomOut)
        XCTAssertFalse(state.canZoomIn)
        XCTAssertTrue(state.canReset)
        XCTAssertEqual(state.zoomPercentage, 400)
    }
}
