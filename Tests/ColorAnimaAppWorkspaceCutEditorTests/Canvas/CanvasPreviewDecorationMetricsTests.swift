import CoreGraphics
import XCTest
@testable import ColorAnimaAppWorkspaceCutEditor

final class CanvasPreviewDecorationMetricsTests: XCTestCase {
    func testCheckerboardTileSizeHasReadableMinimumForSmallImages() {
        let tileSize = CanvasPreviewDecorationMetrics.checkerboardTileSize(
            for: CGRect(x: 0, y: 0, width: 90, height: 60)
        )

        XCTAssertEqual(tileSize, 6)
    }

    func testCheckerboardTileSizeScalesUpForLargeImages() {
        let tileSize = CanvasPreviewDecorationMetrics.checkerboardTileSize(
            for: CGRect(x: 0, y: 0, width: 840, height: 560)
        )

        XCTAssertEqual(tileSize, 20)
    }
}
