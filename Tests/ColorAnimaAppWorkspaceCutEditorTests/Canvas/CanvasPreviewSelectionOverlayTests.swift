import ColorAnimaAppWorkspaceApplication
import CoreGraphics
import XCTest
@testable import ColorAnimaAppWorkspaceCutEditor

final class CanvasPreviewSelectionOverlayTests: XCTestCase {
    func testProjectedSelectionRectMapsBoundingBoxIntoDisplayRect() {
        let projected = CanvasPreviewSelectionOverlayMetrics.projectedSelectionRect(
            CGRect(x: 50, y: 25, width: 100, height: 50),
            imageSize: CGSize(width: 200, height: 100),
            displayRect: CGRect(x: 10, y: 30, width: 400, height: 200)
        )

        XCTAssertEqual(projected.origin.x, 110, accuracy: 0.0001)
        XCTAssertEqual(projected.origin.y, 80, accuracy: 0.0001)
        XCTAssertEqual(projected.size.width, 200, accuracy: 0.0001)
        XCTAssertEqual(projected.size.height, 100, accuracy: 0.0001)
    }

    func testBoundaryPathForSingleRegionIsNonEmpty() {
        let region = makeRegion(pixelIndices: [5, 6, 9, 10])
        let path = CanvasPreviewRegionBoundaryPathBuilder.buildPath(
            for: region,
            imageSize: CGSize(width: 4, height: 4),
            displayRect: CGRect(x: 0, y: 0, width: 40, height: 40)
        )
        XCTAssertFalse(path.isEmpty)
    }

    func testBoundaryPathForEmptyRegionIsEmpty() {
        let region = makeRegion(pixelIndices: [])
        let path = CanvasPreviewRegionBoundaryPathBuilder.buildPath(
            for: region,
            imageSize: CGSize(width: 4, height: 4),
            displayRect: CGRect(x: 0, y: 0, width: 40, height: 40)
        )
        XCTAssertTrue(path.isEmpty)
    }

    func testMultiSelectProducesIndependentPathsPerRegion() {
        let regions = [
            makeRegion(pixelIndices: [0]),
            makeRegion(pixelIndices: [5]),
            makeRegion(pixelIndices: [15]),
        ]
        let imageSize = CGSize(width: 4, height: 4)
        let displayRect = CGRect(x: 0, y: 0, width: 40, height: 40)

        for region in regions {
            let path = CanvasPreviewRegionBoundaryPathBuilder.buildPath(
                for: region,
                imageSize: imageSize,
                displayRect: displayRect
            )
            XCTAssertEqual(path.cgPath.copy()!.countPathElements(), 8)
        }
    }

    func testBoundaryPathScaleFactorIsCorrect() {
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
        XCTAssertFalse(endpoints.isEmpty)
        for point in endpoints {
            XCTAssertTrue(point.x == 0 || point.x == 10)
            XCTAssertTrue(point.y == 0 || point.y == 10)
        }
    }

    func testSameRegionAndSizeProduceIdenticalPaths() {
        let region = makeRegion(pixelIndices: [5, 6, 9, 10])
        let imageSize = CGSize(width: 4, height: 4)
        let displayRect = CGRect(x: 0, y: 0, width: 40, height: 40)

        let path1 = CanvasPreviewRegionBoundaryPathBuilder.buildPath(
            for: region, imageSize: imageSize, displayRect: displayRect
        )
        let path2 = CanvasPreviewRegionBoundaryPathBuilder.buildPath(
            for: region, imageSize: imageSize, displayRect: displayRect
        )

        XCTAssertEqual(
            path1.cgPath.copy()!.pathElementRecords(),
            path2.cgPath.copy()!.pathElementRecords()
        )
    }

    func testDifferentImageSizeProducesDifferentPathCoordinates() {
        let region = makeRegion(pixelIndices: [0])
        let displayRect = CGRect(x: 0, y: 0, width: 40, height: 40)

        let pathSmallImage = CanvasPreviewRegionBoundaryPathBuilder.buildPath(
            for: region,
            imageSize: CGSize(width: 2, height: 2),
            displayRect: displayRect
        )
        let pathLargeImage = CanvasPreviewRegionBoundaryPathBuilder.buildPath(
            for: region,
            imageSize: CGSize(width: 4, height: 4),
            displayRect: displayRect
        )

        XCTAssertNotEqual(
            pathSmallImage.cgPath.copy()!.pathElementRecords(),
            pathLargeImage.cgPath.copy()!.pathElementRecords()
        )
    }

    func testDifferentDisplaySizeProducesDifferentPathCoordinates() {
        let region = makeRegion(pixelIndices: [0])
        let imageSize = CGSize(width: 2, height: 2)

        let pathSmall = CanvasPreviewRegionBoundaryPathBuilder.buildPath(
            for: region,
            imageSize: imageSize,
            displayRect: CGRect(x: 0, y: 0, width: 20, height: 20)
        )
        let pathLarge = CanvasPreviewRegionBoundaryPathBuilder.buildPath(
            for: region,
            imageSize: imageSize,
            displayRect: CGRect(x: 0, y: 0, width: 40, height: 40)
        )

        var smallPoints: [CGPoint] = []
        var largePoints: [CGPoint] = []
        pathSmall.cgPath.applyWithBlock { element in
            if element.pointee.type == .moveToPoint {
                smallPoints.append(element.pointee.points[0])
            }
        }
        pathLarge.cgPath.applyWithBlock { element in
            if element.pointee.type == .moveToPoint {
                largePoints.append(element.pointee.points[0])
            }
        }
        XCTAssertFalse(smallPoints.isEmpty)
        XCTAssertFalse(largePoints.isEmpty)
        let maxSmall = smallPoints.map { max($0.x, $0.y) }.max() ?? 0
        let maxLarge = largePoints.map { max($0.x, $0.y) }.max() ?? 0
        XCTAssertGreaterThan(maxLarge, maxSmall)
    }

    func testDifferentDisplaySizeReusesCachedImageSpaceBoundaryPath() {
        let region = makeRegion(pixelIndices: [5, 6, 9, 10])
        let imageSize = CGSize(width: 4, height: 4)

        CanvasPreviewRegionBoundaryPathBuilder.resetCacheForTesting()

        _ = CanvasPreviewRegionBoundaryPathBuilder.buildPath(
            for: region,
            imageSize: imageSize,
            displayRect: CGRect(x: 0, y: 0, width: 40, height: 40)
        )
        _ = CanvasPreviewRegionBoundaryPathBuilder.buildPath(
            for: region,
            imageSize: imageSize,
            displayRect: CGRect(x: 0, y: 0, width: 80, height: 80)
        )

        XCTAssertEqual(
            CanvasPreviewRegionBoundaryPathBuilder.imageSpaceBuildCountForTesting(
                for: region,
                imageSize: imageSize
            ),
            1
        )
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

    func pathElementRecords() -> [PathElementRecord] {
        var records: [PathElementRecord] = []
        applyWithBlock { element in
            let type = element.pointee.type
            let pointCount: Int
            switch type {
            case .moveToPoint, .addLineToPoint:
                pointCount = 1
            case .addQuadCurveToPoint:
                pointCount = 2
            case .addCurveToPoint:
                pointCount = 3
            case .closeSubpath:
                pointCount = 0
            @unknown default:
                pointCount = 0
            }

            let points = (0..<pointCount).map { element.pointee.points[$0] }
            records.append(PathElementRecord(type: type, points: points))
        }
        return records
    }
}

private struct PathElementRecord: Equatable {
    let type: CGPathElementType
    let points: [CGPoint]
}
