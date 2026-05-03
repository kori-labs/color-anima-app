import CoreGraphics
import XCTest
@testable import ColorAnimaAppWorkspaceApplication

final class CutWorkspaceCanvasPresentationCoordinatorTests: XCTestCase {
    func testPresentationIsNilWithoutOutlineImage() {
        let presentation = CutWorkspaceCanvasPresentationCoordinator.makePresentation(
            from: CutWorkspaceCanvasPresentationState(),
            isRegionDebugOverlayEnabled: false
        )

        XCTAssertNil(presentation)
    }

    func testPresentationUsesOutlineImageSizeAndCarriesSelectionAndVisibility() throws {
        let outline = try makeRasterImage(width: 12, height: 8)
        let overlay = try makeRasterImage(width: 12, height: 8)
        let region = CanvasSelectionRegion(
            area: 4,
            boundingBox: CGRect(x: 1, y: 1, width: 2, height: 2),
            pixelIndices: [0, 1, 2, 3]
        )
        let visibility = LayerVisibility(
            showOutline: true,
            showBaseOverlay: false,
            showHighlightLine: true,
            showShadowLine: false
        )

        let presentation = CutWorkspaceCanvasPresentationCoordinator.makePresentation(
            from: CutWorkspaceCanvasPresentationState(
                outlineImage: outline,
                overlayImage: overlay,
                selectedRegions: [region],
                layerVisibility: visibility
            ),
            isRegionDebugOverlayEnabled: false
        )

        XCTAssertEqual(presentation?.imageSize, CGSize(width: 12, height: 8))
        XCTAssertEqual(presentation?.outlineImage.size, outline.size)
        XCTAssertEqual(presentation?.overlayImage?.size, overlay.size)
        XCTAssertEqual(presentation?.selectedRegions, [region])
        XCTAssertEqual(presentation?.layerVisibility, visibility)
    }

    func testPresentationPreservesOutlineTransparency() throws {
        let outline = try makeRasterImage(
            width: 2,
            height: 2,
            pixels: [
                0, 0, 0, 0, 0, 0, 0, 255,
                255, 255, 255, 255, 255, 255, 255, 255,
            ]
        )

        let presentation = try XCTUnwrap(
            CutWorkspaceCanvasPresentationCoordinator.makePresentation(
                from: CutWorkspaceCanvasPresentationState(outlineImage: outline),
                isRegionDebugOverlayEnabled: false
            )
        )

        XCTAssertEqual(try alphaValues(in: presentation.outlineImage.cgImage), [0, 255, 255, 255])
    }

    func testPreviewLineImagesOverrideLoadedLineArtwork() throws {
        let loadedHighlight = try makeRasterImage(width: 4, height: 4)
        let previewHighlight = try makeRasterImage(width: 5, height: 5)
        let loadedShadow = try makeRasterImage(width: 6, height: 6)
        let previewShadow = try makeRasterImage(width: 7, height: 7)

        let presentation = CutWorkspaceCanvasPresentationCoordinator.makePresentation(
            from: CutWorkspaceCanvasPresentationState(
                outlineImage: try makeRasterImage(width: 10, height: 10),
                highlightLineImage: loadedHighlight,
                highlightLinePreviewImage: previewHighlight,
                shadowLineImage: loadedShadow,
                shadowLinePreviewImage: previewShadow
            ),
            isRegionDebugOverlayEnabled: false
        )

        XCTAssertEqual(presentation?.highlightLineImage?.size, previewHighlight.size)
        XCTAssertEqual(presentation?.shadowLineImage?.size, previewShadow.size)
    }

    func testDebugAnnotationImageRequiresEnabledFlag() throws {
        let debugImage = try makeRasterImage(width: 3, height: 3)

        let disabled = CutWorkspaceCanvasPresentationCoordinator.makePresentation(
            from: CutWorkspaceCanvasPresentationState(
                outlineImage: try makeRasterImage(width: 10, height: 10),
                debugAnnotationImage: debugImage
            ),
            isRegionDebugOverlayEnabled: false
        )
        let enabled = CutWorkspaceCanvasPresentationCoordinator.makePresentation(
            from: CutWorkspaceCanvasPresentationState(
                outlineImage: try makeRasterImage(width: 10, height: 10),
                debugAnnotationImage: debugImage
            ),
            isRegionDebugOverlayEnabled: true
        )

        XCTAssertNil(disabled?.debugAnnotationImage)
        XCTAssertEqual(enabled?.debugAnnotationImage?.size, debugImage.size)
    }

    private func makeRasterImage(width: Int, height: Int) throws -> CanvasRasterImage {
        try makeRasterImage(
            width: width,
            height: height,
            pixels: opaquePixels(width: width, height: height)
        )
    }

    private func makeRasterImage(width: Int, height: Int, pixels: [UInt8]) throws -> CanvasRasterImage {
        guard pixels.count == width * height * 4 else {
            throw TestImageError.invalidPixelBuffer
        }
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let data = Data(pixels) as CFData
        guard let provider = CGDataProvider(data: data), let image = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        ) else {
            throw TestImageError.makeImageFailed
        }
        return CanvasRasterImage(cgImage: image, size: CGSize(width: width, height: height))
    }

    private func opaquePixels(width: Int, height: Int) -> [UInt8] {
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        pixels.indices.filter { $0 % 4 == 3 }.forEach { pixels[$0] = 255 }
        return pixels
    }

    private func alphaValues(in image: CGImage) throws -> [UInt8] {
        guard let data = image.dataProvider?.data, let bytes = CFDataGetBytePtr(data) else {
            throw TestImageError.pixelDataUnavailable
        }
        return stride(from: 3, to: CFDataGetLength(data), by: 4).map { bytes[$0] }
    }

    private enum TestImageError: Error {
        case invalidPixelBuffer
        case makeImageFailed
        case pixelDataUnavailable
    }
}
