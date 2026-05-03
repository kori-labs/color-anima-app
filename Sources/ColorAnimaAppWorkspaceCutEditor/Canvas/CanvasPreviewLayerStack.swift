import ColorAnimaAppWorkspaceApplication
import SwiftUI

extension CanvasPreviewView {
    @ViewBuilder
    func canvasLayerStack(
        presentation: CutWorkspaceCanvasPresentation,
        displayRect: CGRect,
        effectiveZoomScale: CGFloat,
        containerSize: CGSize,
        fittedRect: CGRect,
        dropTargetRegion: CanvasSelectionRegion?
    ) -> some View {
        let visibility = CanvasViewportOverlayVisibility(
            presentation: presentation,
            effectiveZoomScale: effectiveZoomScale,
            committedOffset: committedOffset
        )

        ZStack(alignment: .topTrailing) {
            CanvasViewportChrome(
                displayRect: displayRect,
                effectiveZoomScale: effectiveZoomScale
            ) {
                CanvasViewportOverlayContent(
                    presentation: presentation,
                    displayRect: displayRect,
                    dropTargetRegion: dropTargetRegion
                )
            }

            CanvasPreviewZoomControls(
                effectiveZoomScale: effectiveZoomScale,
                minimumZoomScale: visibility.minimumZoomScale,
                maximumZoomScale: visibility.maximumZoomScale,
                committedOffset: committedOffset,
                onZoomOut: {
                    stepZoom(by: 1 / 1.2, containerSize: containerSize, fittedRect: fittedRect)
                },
                onZoomIn: {
                    stepZoom(by: 1.2, containerSize: containerSize, fittedRect: fittedRect)
                },
                onFit: {
                    resetViewport()
                }
            )
            .padding(14)
        }
    }
}
