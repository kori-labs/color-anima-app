import ColorAnimaAppWorkspaceApplication
import Foundation

package struct CanvasViewportOverlayVisibility {
    let showsBaseOverlay: Bool
    let showsShadowLine: Bool
    let showsHighlightLine: Bool
    let showsOutline: Bool
    let hasSelectionOverlay: Bool
    let hasDebugAnnotation: Bool
    let minimumZoomScale: CGFloat
    let maximumZoomScale: CGFloat
    let zoomControlsState: CanvasPreviewZoomControlsState

    package init(
        presentation: CutWorkspaceCanvasPresentation,
        effectiveZoomScale: CGFloat,
        committedOffset: CGSize
    ) {
        showsBaseOverlay = presentation.layerVisibility.showBaseOverlay
        showsShadowLine = presentation.layerVisibility.showShadowLine
        showsHighlightLine = presentation.layerVisibility.showHighlightLine
        showsOutline = presentation.layerVisibility.showOutline
        hasSelectionOverlay = !presentation.selectedRegions.isEmpty
        hasDebugAnnotation = presentation.debugAnnotationImage != nil
        minimumZoomScale = presentation.minimumZoomScale
        maximumZoomScale = presentation.maximumZoomScale
        zoomControlsState = CanvasPreviewZoomControlsState(
            effectiveZoomScale: effectiveZoomScale,
            minimumZoomScale: minimumZoomScale,
            maximumZoomScale: maximumZoomScale,
            committedOffset: committedOffset
        )
    }
}
