import CoreGraphics
import Foundation

public struct CutWorkspaceCanvasPresentationState {
    public var outlineImage: CanvasRasterImage?
    public var overlayImage: CanvasRasterImage?
    public var highlightLineImage: CanvasRasterImage?
    public var highlightLinePreviewImage: CanvasRasterImage?
    public var shadowLineImage: CanvasRasterImage?
    public var shadowLinePreviewImage: CanvasRasterImage?
    public var debugAnnotationImage: CanvasRasterImage?
    public var selectedRegions: [CanvasSelectionRegion]
    public var layerVisibility: LayerVisibility

    public init(
        outlineImage: CanvasRasterImage? = nil,
        overlayImage: CanvasRasterImage? = nil,
        highlightLineImage: CanvasRasterImage? = nil,
        highlightLinePreviewImage: CanvasRasterImage? = nil,
        shadowLineImage: CanvasRasterImage? = nil,
        shadowLinePreviewImage: CanvasRasterImage? = nil,
        debugAnnotationImage: CanvasRasterImage? = nil,
        selectedRegions: [CanvasSelectionRegion] = [],
        layerVisibility: LayerVisibility = LayerVisibility()
    ) {
        self.outlineImage = outlineImage
        self.overlayImage = overlayImage
        self.highlightLineImage = highlightLineImage
        self.highlightLinePreviewImage = highlightLinePreviewImage
        self.shadowLineImage = shadowLineImage
        self.shadowLinePreviewImage = shadowLinePreviewImage
        self.debugAnnotationImage = debugAnnotationImage
        self.selectedRegions = selectedRegions
        self.layerVisibility = layerVisibility
    }
}

public enum CutWorkspaceCanvasPresentationCoordinator {
    public static func makePresentation(
        from state: CutWorkspaceCanvasPresentationState,
        isRegionDebugOverlayEnabled: Bool
    ) -> CutWorkspaceCanvasPresentation? {
        guard let outlineImage = state.outlineImage else {
            return nil
        }

        return CutWorkspaceCanvasPresentation(
            imageSize: outlineImage.size,
            outlineImage: outlineImage,
            overlayImage: state.overlayImage,
            highlightLineImage: state.highlightLinePreviewImage ?? state.highlightLineImage,
            shadowLineImage: state.shadowLinePreviewImage ?? state.shadowLineImage,
            debugAnnotationImage: isRegionDebugOverlayEnabled ? state.debugAnnotationImage : nil,
            selectedRegions: state.selectedRegions,
            layerVisibility: state.layerVisibility
        )
    }
}
