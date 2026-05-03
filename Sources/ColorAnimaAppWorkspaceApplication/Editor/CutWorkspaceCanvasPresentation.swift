import CoreGraphics
import Foundation

public struct CutWorkspaceCanvasPresentation {
    public let imageSize: CGSize
    public let outlineImage: CanvasRasterImage
    public let overlayImage: CanvasRasterImage?
    public let highlightLineImage: CanvasRasterImage?
    public let shadowLineImage: CanvasRasterImage?
    public let debugAnnotationImage: CanvasRasterImage?
    public let selectedRegions: [CanvasSelectionRegion]
    public let layerVisibility: LayerVisibility
    public let minimumZoomScale: CGFloat
    public let maximumZoomScale: CGFloat

    public init(
        imageSize: CGSize,
        outlineImage: CanvasRasterImage,
        overlayImage: CanvasRasterImage?,
        highlightLineImage: CanvasRasterImage?,
        shadowLineImage: CanvasRasterImage?,
        debugAnnotationImage: CanvasRasterImage?,
        selectedRegions: [CanvasSelectionRegion] = [],
        layerVisibility: LayerVisibility,
        minimumZoomScale: CGFloat = 1,
        maximumZoomScale: CGFloat = 8
    ) {
        self.imageSize = imageSize
        self.outlineImage = outlineImage
        self.overlayImage = overlayImage
        self.highlightLineImage = highlightLineImage
        self.shadowLineImage = shadowLineImage
        self.debugAnnotationImage = debugAnnotationImage
        self.selectedRegions = selectedRegions
        self.layerVisibility = layerVisibility
        self.minimumZoomScale = minimumZoomScale
        self.maximumZoomScale = maximumZoomScale
    }
}
