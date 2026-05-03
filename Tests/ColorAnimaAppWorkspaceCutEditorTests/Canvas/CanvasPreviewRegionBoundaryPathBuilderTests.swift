import ColorAnimaAppWorkspaceApplication
import CoreGraphics
import XCTest
@testable import ColorAnimaAppWorkspaceCutEditor

final class CanvasPreviewRegionBoundaryPathBuilderTests: XCTestCase {
    func testSolidBlockProducesExpectedEdgeCount() {
        let region = makeRegion(pixelIndices: [5, 6, 9, 10])

        let path = CanvasPreviewRegionBoundaryPathBuilder.buildPath(
            for: region,
            imageSize: CGSize(width: 4, height: 4),
            displayRect: CGRect(x: 0, y: 0, width: 40, height: 40)
        )

        XCTAssertEqual(path.cgPath.copy()!.countPathElements(), 8)
    }

    func testSinglePixelProducesFourEdgePairs() {
        let region = makeRegion(pixelIndices: [0])

        let path = CanvasPreviewRegionBoundaryPathBuilder.buildPath(
            for: region,
            imageSize: CGSize(width: 4, height: 4),
            displayRect: CGRect(x: 0, y: 0, width: 40, height: 40)
        )

        XCTAssertEqual(path.cgPath.copy()!.countPathElements(), 8)
    }

    func testScaleFactorAppliedCorrectly() {
        let region = makeRegion(pixelIndices: [0])

        let path = CanvasPreviewRegionBoundaryPathBuilder.buildPath(
            for: region,
            imageSize: CGSize(width: 2, height: 2),
            displayRect: CGRect(x: 0, y: 0, width: 20, height: 20)
        )

        var endpoints: [CGPoint] = []
        path.cgPath.applyWithBlock { element in
            switch element.pointee.type {
            case .moveToPoint, .addLineToPoint:
                endpoints.append(element.pointee.points[0])
            default:
                break
            }
        }

        for point in endpoints {
            XCTAssertTrue(point.x == 0 || point.x == 10)
            XCTAssertTrue(point.y == 0 || point.y == 10)
        }
    }

    func testEmptyPixelIndicesProducesEmptyPath() {
        let region = makeRegion(pixelIndices: [])

        let path = CanvasPreviewRegionBoundaryPathBuilder.buildPath(
            for: region,
            imageSize: CGSize(width: 4, height: 4),
            displayRect: CGRect(x: 0, y: 0, width: 40, height: 40)
        )

        XCTAssertTrue(path.isEmpty)
    }

    func testZeroRoundedImageDimensionProducesEmptyPath() {
        let region = makeRegion(pixelIndices: [0])

        let zeroWidthPath = CanvasPreviewRegionBoundaryPathBuilder.buildPath(
            for: region,
            imageSize: CGSize(width: 0.4, height: 4),
            displayRect: CGRect(x: 0, y: 0, width: 40, height: 40)
        )
        let zeroHeightPath = CanvasPreviewRegionBoundaryPathBuilder.buildPath(
            for: region,
            imageSize: CGSize(width: 4, height: 0.4),
            displayRect: CGRect(x: 0, y: 0, width: 40, height: 40)
        )

        XCTAssertTrue(zeroWidthPath.isEmpty)
        XCTAssertTrue(zeroHeightPath.isEmpty)
    }

    private func makeRegion(pixelIndices: [Int]) -> CanvasSelectionRegion {
        CanvasSelectionRegion(
            area: pixelIndices.count,
            boundingBox: .zero,
            pixelIndices: pixelIndices
        )
    }
}

private extension CGPath {
    func countPathElements() -> Int {
        var count = 0
        applyWithBlock { _ in count += 1 }
        return count
    }
}
