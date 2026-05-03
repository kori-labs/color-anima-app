import CoreGraphics

enum CanvasPreviewLayoutMath {
    static func aspectFitRect(imageSize: CGSize, in containerSize: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0, containerSize.width > 0, containerSize.height > 0 else {
            return .zero
        }

        let scale = min(containerSize.width / imageSize.width, containerSize.height / imageSize.height)
        let width = imageSize.width * scale
        let height = imageSize.height * scale
        let originX = (containerSize.width - width) * 0.5
        let originY = (containerSize.height - height) * 0.5
        return CGRect(x: originX, y: originY, width: width, height: height)
    }

    static func scaledRect(from fittedRect: CGRect, zoomScale: CGFloat, offset: CGSize) -> CGRect {
        let scaledWidth = fittedRect.width * zoomScale
        let scaledHeight = fittedRect.height * zoomScale

        return CGRect(
            x: fittedRect.midX - (scaledWidth * 0.5) + offset.width,
            y: fittedRect.midY - (scaledHeight * 0.5) + offset.height,
            width: scaledWidth,
            height: scaledHeight
        )
    }

    static func mapViewPointToImage(_ point: CGPoint, imageSize: CGSize, displayRect: CGRect) -> CGPoint? {
        guard displayRect.width > 0, displayRect.height > 0 else { return nil }
        let normalizedX = (point.x - displayRect.minX) / displayRect.width
        let normalizedY = (point.y - displayRect.minY) / displayRect.height
        guard normalizedX >= 0, normalizedX <= 1, normalizedY >= 0, normalizedY <= 1 else {
            return nil
        }
        return CGPoint(
            x: normalizedX * imageSize.width,
            y: normalizedY * imageSize.height
        )
    }

    static func clampedZoom(
        _ proposedZoomScale: CGFloat,
        minimumZoomScale: CGFloat,
        maximumZoomScale: CGFloat
    ) -> CGFloat {
        min(max(proposedZoomScale, minimumZoomScale), maximumZoomScale)
    }

    static func clampedOffset(
        _ proposedOffset: CGSize,
        containerSize: CGSize,
        fittedRect: CGRect,
        zoomScale: CGFloat
    ) -> CGSize {
        guard fittedRect.width > 0,
              fittedRect.height > 0,
              containerSize.width > 0,
              containerSize.height > 0 else {
            return .zero
        }

        let displayWidth = fittedRect.width * zoomScale
        let displayHeight = fittedRect.height * zoomScale
        let overscrollAllowance = CanvasPreviewDecorationMetrics.viewportOverscrollAllowance(for: containerSize)
        let horizontalLimit = abs(containerSize.width - displayWidth) * 0.5 + overscrollAllowance
        let verticalLimit = abs(containerSize.height - displayHeight) * 0.5 + overscrollAllowance

        return CGSize(
            width: min(max(proposedOffset.width, -horizontalLimit), horizontalLimit),
            height: min(max(proposedOffset.height, -verticalLimit), verticalLimit)
        )
    }

    static func projectBoundingBox(_ bbox: CGRect, imageSize: CGSize, into fittedRect: CGRect) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return .zero }

        return CGRect(
            x: fittedRect.minX + (bbox.minX / imageSize.width) * fittedRect.width,
            y: fittedRect.minY + (bbox.minY / imageSize.height) * fittedRect.height,
            width: (bbox.width / imageSize.width) * fittedRect.width,
            height: (bbox.height / imageSize.height) * fittedRect.height
        )
    }
}
