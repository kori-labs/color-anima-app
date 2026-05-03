import CoreGraphics
import Foundation

public struct CanvasRasterImage {
    public let cgImage: CGImage
    public let size: CGSize

    public init(cgImage: CGImage, size: CGSize) {
        self.cgImage = cgImage
        self.size = size
    }

    public var bounds: CGRect {
        CGRect(origin: .zero, size: size)
    }
}
