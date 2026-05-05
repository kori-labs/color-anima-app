import ColorAnimaAppWorkspaceApplication
import SwiftUI

package struct CanvasViewportOverlayStack: View {
    let presentation: CutWorkspaceCanvasPresentation
    let displayRect: CGRect
    let effectiveZoomScale: CGFloat
    let committedOffset: CGSize
    let onZoomOut: () -> Void
    let onZoomIn: () -> Void
    let onFit: () -> Void

    package init(
        presentation: CutWorkspaceCanvasPresentation,
        displayRect: CGRect,
        effectiveZoomScale: CGFloat,
        committedOffset: CGSize,
        onZoomOut: @escaping () -> Void,
        onZoomIn: @escaping () -> Void,
        onFit: @escaping () -> Void
    ) {
        self.presentation = presentation
        self.displayRect = displayRect
        self.effectiveZoomScale = effectiveZoomScale
        self.committedOffset = committedOffset
        self.onZoomOut = onZoomOut
        self.onZoomIn = onZoomIn
        self.onFit = onFit
    }

    private var visibility: CanvasViewportOverlayVisibility {
        CanvasViewportOverlayVisibility(
            presentation: presentation,
            effectiveZoomScale: effectiveZoomScale,
            committedOffset: committedOffset
        )
    }

    package var body: some View {
        ZStack(alignment: .topTrailing) {
            CanvasViewportOverlayContent(
                presentation: presentation,
                displayRect: displayRect
            )

            CanvasPreviewZoomControls(
                effectiveZoomScale: effectiveZoomScale,
                minimumZoomScale: visibility.minimumZoomScale,
                maximumZoomScale: visibility.maximumZoomScale,
                committedOffset: committedOffset,
                onZoomOut: onZoomOut,
                onZoomIn: onZoomIn,
                onFit: onFit
            )
            .padding(14) // TODO: off-grid; snap to space3(12) or space4(16) in follow-up
        }
    }
}
