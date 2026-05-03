import CoreGraphics
import Foundation

public struct CanvasSelectionRegion: Identifiable, Hashable, Equatable, Sendable {
    public let id: UUID
    public var area: Int
    public var boundingBox: CGRect
    public private(set) var pixels: Set<UInt32>
    public var isBackgroundCandidate: Bool

    public var sortedPixels: [UInt32] {
        pixels.sorted()
    }

    public init(
        id: UUID = UUID(),
        area: Int,
        boundingBox: CGRect,
        pixels: Set<UInt32>,
        isBackgroundCandidate: Bool = false
    ) {
        self.id = id
        self.area = area
        self.boundingBox = boundingBox
        self.pixels = pixels
        self.isBackgroundCandidate = isBackgroundCandidate
    }

    public init(
        id: UUID = UUID(),
        area: Int,
        boundingBox: CGRect,
        pixelIndices: [Int],
        isBackgroundCandidate: Bool = false
    ) {
        self.init(
            id: id,
            area: area,
            boundingBox: boundingBox,
            pixels: Set(pixelIndices.compactMap { $0 >= 0 ? UInt32($0) : nil }),
            isBackgroundCandidate: isBackgroundCandidate
        )
    }

    public func contains(pixelIndex: Int) -> Bool {
        guard pixelIndex >= 0 else { return false }
        return pixels.contains(UInt32(pixelIndex))
    }
}
