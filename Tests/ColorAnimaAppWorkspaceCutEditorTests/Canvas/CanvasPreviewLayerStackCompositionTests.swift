import ColorAnimaAppWorkspaceApplication
import CoreGraphics
import XCTest
@testable import ColorAnimaAppWorkspaceCutEditor

@MainActor
final class CanvasPreviewLayerStackCompositionTests: XCTestCase {
    func testViewportChromeStateUsesDecorationMetrics() {
        let displayRect = CGRect(x: 12, y: 20, width: 560, height: 420)
        let state = CanvasViewportChromeState(displayRect: displayRect, effectiveZoomScale: 2.25)

        XCTAssertEqual(state.displayRect, displayRect)
        XCTAssertEqual(state.tileSize, CanvasPreviewDecorationMetrics.checkerboardTileSize(for: displayRect))
        XCTAssertEqual(
            state.strokeWidth,
            CanvasPreviewDecorationMetrics.imageBoundsStrokeWidth(for: 2.25),
            accuracy: 0.0001
        )
    }

    func testViewportOverlayContentStoresPresentationAndDisplayRect() throws {
        let rasterImage = try makeRasterImage()
        let presentation = CutWorkspaceCanvasPresentation(
            imageSize: CGSize(width: 120, height: 80),
            outlineImage: rasterImage,
            overlayImage: rasterImage,
            highlightLineImage: nil,
            shadowLineImage: rasterImage,
            debugAnnotationImage: rasterImage,
            layerVisibility: LayerVisibility(
                showOutline: true,
                showBaseOverlay: false,
                showHighlightLine: true,
                showShadowLine: false
            ),
            minimumZoomScale: 1,
            maximumZoomScale: 4
        )
        let displayRect = CGRect(x: 12, y: 20, width: 560, height: 420)

        let content = CanvasViewportOverlayContent(
            presentation: presentation,
            displayRect: displayRect
        )

        XCTAssertEqual(content.displayRect, displayRect)
        XCTAssertEqual(content.localDisplayRect, CGRect(origin: .zero, size: displayRect.size))
        XCTAssertEqual(content.presentation.imageSize, presentation.imageSize)
        XCTAssertTrue(content.presentation.layerVisibility.showOutline)
    }

    func testViewportOverlayVisibilityReflectsPresentationVisibilityAndPresence() throws {
        let rasterImage = try makeRasterImage()
        let selectedRegion = CanvasSelectionRegion(
            area: 1,
            boundingBox: CGRect(x: 15, y: 10, width: 36, height: 22),
            pixelIndices: [0]
        )
        let presentation = CutWorkspaceCanvasPresentation(
            imageSize: CGSize(width: 120, height: 80),
            outlineImage: rasterImage,
            overlayImage: rasterImage,
            highlightLineImage: nil,
            shadowLineImage: rasterImage,
            debugAnnotationImage: rasterImage,
            selectedRegions: [selectedRegion],
            layerVisibility: LayerVisibility(
                showOutline: true,
                showBaseOverlay: false,
                showHighlightLine: true,
                showShadowLine: false
            ),
            minimumZoomScale: 1,
            maximumZoomScale: 4
        )

        let visibility = CanvasViewportOverlayVisibility(
            presentation: presentation,
            effectiveZoomScale: 2,
            committedOffset: CGSize(width: 8, height: -6)
        )

        XCTAssertFalse(visibility.showsBaseOverlay)
        XCTAssertFalse(visibility.showsShadowLine)
        XCTAssertTrue(visibility.showsHighlightLine)
        XCTAssertTrue(visibility.showsOutline)
        XCTAssertTrue(visibility.hasSelectionOverlay)
        XCTAssertTrue(visibility.hasDebugAnnotation)
        XCTAssertEqual(visibility.minimumZoomScale, 1)
        XCTAssertEqual(visibility.maximumZoomScale, 4)
        XCTAssertTrue(visibility.zoomControlsState.canZoomOut)
        XCTAssertTrue(visibility.zoomControlsState.canZoomIn)
        XCTAssertTrue(visibility.zoomControlsState.canReset)
        XCTAssertEqual(visibility.zoomControlsState.zoomPercentage, 200)
    }

    private func makeRasterImage() throws -> CanvasRasterImage {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ), let image = context.makeImage() else {
            throw TestImageError.makeImageFailed
        }
        return CanvasRasterImage(cgImage: image, size: CGSize(width: 1, height: 1))
    }
}

private enum TestImageError: Error {
    case makeImageFailed
}
