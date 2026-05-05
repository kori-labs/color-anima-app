import ColorAnimaAppWorkspaceDesignSystem
import SwiftUI

package struct CanvasViewportChrome<Content: View>: View {
    let state: CanvasViewportChromeState
    private let content: Content

    package init(
        displayRect: CGRect,
        effectiveZoomScale: CGFloat,
        @ViewBuilder content: () -> Content
    ) {
        self.state = CanvasViewportChromeState(
            displayRect: displayRect,
            effectiveZoomScale: effectiveZoomScale
        )
        self.content = content()
    }

    package var body: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: WorkspaceFoundation.Metrics.frameCardCornerRadius)
                .fill(WorkspaceChromeStyle.viewportFill)

            CanvasImageBoundsPlate(
                tileSize: state.tileSize,
                strokeWidth: state.strokeWidth
            )

            content
        }
        .frame(width: state.displayRect.width, height: state.displayRect.height)
        .position(x: state.displayRect.midX, y: state.displayRect.midY)
    }
}

package struct CanvasViewportChromeState {
    let displayRect: CGRect
    let tileSize: CGFloat
    let strokeWidth: CGFloat

    package init(displayRect: CGRect, effectiveZoomScale: CGFloat) {
        self.displayRect = displayRect
        tileSize = CanvasPreviewDecorationMetrics.checkerboardTileSize(for: displayRect)
        strokeWidth = CanvasPreviewDecorationMetrics.imageBoundsStrokeWidth(for: effectiveZoomScale)
    }
}
