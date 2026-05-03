import ColorAnimaAppWorkspaceApplication
import SwiftUI

package struct CanvasViewportOverlayContent: View {
    let presentation: CutWorkspaceCanvasPresentation
    let displayRect: CGRect
    let dropTargetRegion: CanvasSelectionRegion?

    package var localDisplayRect: CGRect {
        CGRect(origin: .zero, size: displayRect.size)
    }

    package init(
        presentation: CutWorkspaceCanvasPresentation,
        displayRect: CGRect,
        dropTargetRegion: CanvasSelectionRegion? = nil
    ) {
        self.presentation = presentation
        self.displayRect = displayRect
        self.dropTargetRegion = dropTargetRegion
    }

    package var body: some View {
        ZStack {
            CanvasPreviewImageLayers(
                presentation: presentation,
                displayRect: displayRect
            )

            CanvasPreviewSelectionOverlay(
                presentation: presentation,
                displayRect: localDisplayRect
            )

            CanvasPreviewDropTargetOverlay(
                region: dropTargetRegion,
                imageSize: presentation.imageSize,
                displayRect: localDisplayRect
            )

            CanvasPreviewDebugAnnotationOverlay(
                debugAnnotationImage: presentation.debugAnnotationImage,
                displayRect: displayRect
            )
        }
    }
}
