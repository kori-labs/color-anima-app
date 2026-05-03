import AppKit
import ColorAnimaAppWorkspaceApplication
import SwiftUI

extension CanvasPreviewView {
    func canvasTapGesture(imageSize: CGSize, displayRect: CGRect) -> some Gesture {
        SpatialTapGesture()
            .onEnded { value in
                let modifiers = currentWorkspaceSelectionModifiers()
                guard displayRect.contains(value.location),
                      let point = CanvasPreviewLayoutMath.mapViewPointToImage(
                        value.location,
                        imageSize: imageSize,
                        displayRect: displayRect
                      )
                else {
                    onSelectImagePoint(nil, nil)
                    return
                }
                onSelectImagePoint(point, modifiers.isEmpty ? nil : modifiers)
            }
    }

    func canvasDragGesture(
        containerSize: CGSize,
        fittedRect: CGRect,
        effectiveZoomScale: CGFloat
    ) -> some Gesture {
        DragGesture(minimumDistance: 2)
            .updating($dragTranslation) { value, state, _ in
                let modifierFlags = NSEvent.modifierFlags
                guard !modifierFlags.contains(.shift) else { return }
                state = value.translation
            }
            .onEnded { value in
                let modifierFlags = NSEvent.modifierFlags
                guard !modifierFlags.contains(.shift) else { return }
                let proposedOffset = CGSize(
                    width: committedOffset.width + value.translation.width,
                    height: committedOffset.height + value.translation.height
                )
                committedOffset = CanvasPreviewLayoutMath.clampedOffset(
                    proposedOffset,
                    containerSize: containerSize,
                    fittedRect: fittedRect,
                    zoomScale: effectiveZoomScale
                )
            }
    }

    func canvasMagnificationGesture(
        containerSize: CGSize,
        fittedRect: CGRect
    ) -> some Gesture {
        MagnificationGesture()
            .updating($gestureMagnification) { value, state, _ in
                state = value
            }
            .onEnded { value in
                let updatedZoomScale = CanvasPreviewLayoutMath.clampedZoom(
                    zoomScale * value,
                    minimumZoomScale: presentation.minimumZoomScale,
                    maximumZoomScale: presentation.maximumZoomScale
                )
                zoomScale = updatedZoomScale
                committedOffset = CanvasPreviewLayoutMath.clampedOffset(
                    committedOffset,
                    containerSize: containerSize,
                    fittedRect: fittedRect,
                    zoomScale: updatedZoomScale
                )
            }
    }

    func stepZoom(by multiplier: CGFloat, containerSize: CGSize, fittedRect: CGRect) {
        let updatedZoomScale = CanvasPreviewLayoutMath.clampedZoom(
            zoomScale * multiplier,
            minimumZoomScale: presentation.minimumZoomScale,
            maximumZoomScale: presentation.maximumZoomScale
        )
        zoomScale = updatedZoomScale
        committedOffset = CanvasPreviewLayoutMath.clampedOffset(
            committedOffset,
            containerSize: containerSize,
            fittedRect: fittedRect,
            zoomScale: updatedZoomScale
        )
    }

    func resetViewport() {
        zoomScale = presentation.minimumZoomScale
        committedOffset = .zero
    }

    private func currentWorkspaceSelectionModifiers() -> WorkspaceSelectionModifiers {
        let modifierFlags = NSEvent.modifierFlags
        var modifiers = WorkspaceSelectionModifiers()
        if modifierFlags.contains(.command) {
            modifiers.insert(.additive)
        }
        if modifierFlags.contains(.shift) {
            modifiers.insert(.range)
        }
        return modifiers
    }
}
