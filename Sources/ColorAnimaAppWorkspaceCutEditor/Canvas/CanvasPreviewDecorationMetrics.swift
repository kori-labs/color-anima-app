import CoreGraphics

enum CanvasPreviewDecorationMetrics {
    static func checkerboardTileSize(for displayRect: CGRect) -> CGFloat {
        max(round(min(displayRect.width, displayRect.height) / 28), 6)
    }

    static func viewportOverscrollAllowance(for containerSize: CGSize) -> CGFloat {
        max(round(min(containerSize.width, containerSize.height) / 8), 48)
    }

    static func imageBoundsStrokeWidth(for zoomScale: CGFloat) -> CGFloat {
        max(1, 1.5 / sqrt(max(zoomScale, 1)))
    }
}
