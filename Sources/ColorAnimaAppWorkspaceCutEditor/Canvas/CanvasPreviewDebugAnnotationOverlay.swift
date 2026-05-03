import ColorAnimaAppWorkspaceApplication
import SwiftUI

package struct CanvasPreviewDebugAnnotationOverlay: View {
    let debugAnnotationImage: CanvasRasterImage?
    let displayRect: CGRect

    package init(debugAnnotationImage: CanvasRasterImage?, displayRect: CGRect) {
        self.debugAnnotationImage = debugAnnotationImage
        self.displayRect = displayRect
    }

    package var body: some View {
        if let debugAnnotationImage {
            Image(decorative: debugAnnotationImage.cgImage, scale: 1, orientation: .up)
                .resizable()
                .interpolation(.none)
                .frame(width: displayRect.width, height: displayRect.height)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}
