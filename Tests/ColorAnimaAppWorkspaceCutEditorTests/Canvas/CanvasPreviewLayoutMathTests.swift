import CoreGraphics
import XCTest
@testable import ColorAnimaAppWorkspaceCutEditor

final class CanvasPreviewLayoutMathTests: XCTestCase {
    func testAspectFitRectCentersImageWithinContainer() {
        let rect = CanvasPreviewLayoutMath.aspectFitRect(
            imageSize: CGSize(width: 400, height: 200),
            in: CGSize(width: 1000, height: 800)
        )

        XCTAssertEqual(rect.origin.x, 0, accuracy: 0.0001)
        XCTAssertEqual(rect.origin.y, 150, accuracy: 0.0001)
        XCTAssertEqual(rect.size.width, 1000, accuracy: 0.0001)
        XCTAssertEqual(rect.size.height, 500, accuracy: 0.0001)
    }

    func testClampedOffsetRespectsOverscrollAllowance() {
        let fittedRect = CGRect(x: 0, y: 0, width: 100, height: 60)
        let clamped = CanvasPreviewLayoutMath.clampedOffset(
            CGSize(width: 500, height: -500),
            containerSize: CGSize(width: 320, height: 240),
            fittedRect: fittedRect,
            zoomScale: 1.5
        )

        XCTAssertEqual(clamped.width, 133, accuracy: 0.0001)
        XCTAssertEqual(clamped.height, -123, accuracy: 0.0001)
    }

    func testMapViewPointToImageMapsProportionally() {
        let mapped = CanvasPreviewLayoutMath.mapViewPointToImage(
            CGPoint(x: 60, y: 55),
            imageSize: CGSize(width: 200, height: 100),
            displayRect: CGRect(x: 10, y: 30, width: 100, height: 50)
        )

        XCTAssertEqual(mapped?.x ?? -1, 100, accuracy: 0.0001)
        XCTAssertEqual(mapped?.y ?? -1, 50, accuracy: 0.0001)
    }

    func testMapViewPointToImageReturnsNilOutsideDisplayRect() {
        let mapped = CanvasPreviewLayoutMath.mapViewPointToImage(
            CGPoint(x: 9, y: 29),
            imageSize: CGSize(width: 200, height: 100),
            displayRect: CGRect(x: 10, y: 30, width: 100, height: 50)
        )

        XCTAssertNil(mapped)
    }
}
