import CoreGraphics
import XCTest
@testable import ColorAnimaAppWorkspaceApplication

final class CutWorkspaceRegionHitTestingTests: XCTestCase {
    func testRegionReturnsRegionContainingImagePoint() {
        let regionID = UUID()
        let region = CanvasSelectionRegion(
            id: regionID,
            area: 4,
            boundingBox: CGRect(x: 1, y: 1, width: 2, height: 2),
            pixelIndices: [5, 6, 9, 10]
        )

        let hit = CutWorkspaceRegionHitTesting.region(
            at: CGPoint(x: 1.5, y: 1.2),
            imageSize: CGSize(width: 4, height: 4),
            in: [region]
        )

        XCTAssertEqual(hit?.id, regionID)
    }

    func testRegionReturnsNilOutsideImageBounds() {
        let region = CanvasSelectionRegion(
            area: 1,
            boundingBox: CGRect(x: 0, y: 0, width: 1, height: 1),
            pixelIndices: [0]
        )

        let hit = CutWorkspaceRegionHitTesting.region(
            at: CGPoint(x: 4, y: 0),
            imageSize: CGSize(width: 4, height: 4),
            in: [region]
        )

        XCTAssertNil(hit)
    }

    func testRegionUsesPixelMembershipInsideBoundingBox() {
        let region = CanvasSelectionRegion(
            area: 1,
            boundingBox: CGRect(x: 1, y: 1, width: 2, height: 2),
            pixelIndices: [5]
        )

        let hit = CutWorkspaceRegionHitTesting.region(
            at: CGPoint(x: 2, y: 2),
            imageSize: CGSize(width: 4, height: 4),
            in: [region]
        )

        XCTAssertNil(hit)
    }

    func testRegionCanExcludeBackgroundCandidates() {
        let background = CanvasSelectionRegion(
            area: 1,
            boundingBox: CGRect(x: 0, y: 0, width: 1, height: 1),
            pixelIndices: [0],
            isBackgroundCandidate: true
        )
        let foregroundID = UUID()
        let foreground = CanvasSelectionRegion(
            id: foregroundID,
            area: 1,
            boundingBox: CGRect(x: 0, y: 0, width: 1, height: 1),
            pixelIndices: [0]
        )

        let hit = CutWorkspaceRegionHitTesting.region(
            at: .zero,
            imageSize: CGSize(width: 4, height: 4),
            in: [background, foreground],
            excludingBackgroundCandidates: true
        )

        XCTAssertEqual(hit?.id, foregroundID)
    }
}
