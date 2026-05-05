import ColorAnimaAppWorkspaceDesignSystem
import SwiftUI

package struct CanvasPreviewZoomControls: View {
    let effectiveZoomScale: CGFloat
    let minimumZoomScale: CGFloat
    let maximumZoomScale: CGFloat
    let committedOffset: CGSize
    let onZoomOut: () -> Void
    let onZoomIn: () -> Void
    let onFit: () -> Void

    package init(
        effectiveZoomScale: CGFloat,
        minimumZoomScale: CGFloat,
        maximumZoomScale: CGFloat,
        committedOffset: CGSize,
        onZoomOut: @escaping () -> Void,
        onZoomIn: @escaping () -> Void,
        onFit: @escaping () -> Void
    ) {
        self.effectiveZoomScale = effectiveZoomScale
        self.minimumZoomScale = minimumZoomScale
        self.maximumZoomScale = maximumZoomScale
        self.committedOffset = committedOffset
        self.onZoomOut = onZoomOut
        self.onZoomIn = onZoomIn
        self.onFit = onFit
    }

    private var state: CanvasPreviewZoomControlsState {
        CanvasPreviewZoomControlsState(
            effectiveZoomScale: effectiveZoomScale,
            minimumZoomScale: minimumZoomScale,
            maximumZoomScale: maximumZoomScale,
            committedOffset: committedOffset
        )
    }

    package var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            HStack(spacing: 8) {
                Button("-") {
                    onZoomOut()
                }
                .disabled(!state.canZoomOut)
                .accessibilityLabel("Zoom Out")

                Text("\(state.zoomPercentage)%")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .frame(minWidth: 54)
                    .accessibilityLabel("Zoom Level")
                    .accessibilityValue("\(state.zoomPercentage) percent")

                Button("+") {
                    onZoomIn()
                }
                .disabled(!state.canZoomIn)
                .accessibilityLabel("Zoom In")
            }

            Button("Fit") {
                onFit()
            }
            .disabled(!state.canReset)
        }
        .buttonStyle(.bordered)
        .padding(WorkspaceFoundation.Metrics.space2_5)
        .background(WorkspaceChromeStyle.overlayPanelFill)
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(WorkspaceChromeStyle.overlayPanelStroke, lineWidth: 1)
        }
        .clipShape(.rect(cornerRadius: 14))
    }
}

package struct CanvasPreviewZoomControlsState {
    let canZoomOut: Bool
    let canZoomIn: Bool
    let canReset: Bool
    let zoomPercentage: Int

    package init(
        effectiveZoomScale: CGFloat,
        minimumZoomScale: CGFloat,
        maximumZoomScale: CGFloat,
        committedOffset: CGSize
    ) {
        canZoomOut = effectiveZoomScale > minimumZoomScale
        canZoomIn = effectiveZoomScale < maximumZoomScale
        canReset = effectiveZoomScale != minimumZoomScale || committedOffset != .zero
        zoomPercentage = Int((effectiveZoomScale * 100).rounded())
    }
}
