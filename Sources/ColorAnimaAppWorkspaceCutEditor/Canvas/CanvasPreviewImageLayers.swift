import ColorAnimaAppWorkspaceApplication
import SwiftUI

package struct CanvasPreviewImageLayers: View {
    let presentation: CutWorkspaceCanvasPresentation
    let displayRect: CGRect

    package init(presentation: CutWorkspaceCanvasPresentation, displayRect: CGRect) {
        self.presentation = presentation
        self.displayRect = displayRect
    }

    package var body: some View {
        Group {
            if presentation.layerVisibility.showBaseOverlay, let overlayImage = presentation.overlayImage {
                imageLayer(overlayImage)
            }

            if presentation.layerVisibility.showShadowLine, let shadowLineImage = presentation.shadowLineImage {
                imageLayer(shadowLineImage)
            }

            if presentation.layerVisibility.showHighlightLine, let highlightLineImage = presentation.highlightLineImage {
                imageLayer(highlightLineImage)
            }

            if presentation.layerVisibility.showOutline {
                imageLayer(presentation.outlineImage)
            }
        }
    }

    @ViewBuilder
    private func imageLayer(_ image: CanvasRasterImage) -> some View {
        Image(decorative: image.cgImage, scale: 1, orientation: .up)
            .resizable()
            .interpolation(.none)
            .frame(width: displayRect.width, height: displayRect.height)
    }
}
