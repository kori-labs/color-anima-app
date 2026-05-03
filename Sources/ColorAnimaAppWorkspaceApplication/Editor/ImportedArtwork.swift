import CoreGraphics
import Foundation

public struct ImportedArtwork {
    public let url: URL
    public let cgImage: CGImage
    public let size: CGSize

    public init(url: URL, cgImage: CGImage, size: CGSize? = nil) {
        self.url = url
        self.cgImage = cgImage
        self.size = size ?? CGSize(width: cgImage.width, height: cgImage.height)
    }

    public var canvasRasterImage: CanvasRasterImage {
        CanvasRasterImage(cgImage: cgImage, size: size)
    }
}

extension ImportedArtwork: @unchecked Sendable {}
