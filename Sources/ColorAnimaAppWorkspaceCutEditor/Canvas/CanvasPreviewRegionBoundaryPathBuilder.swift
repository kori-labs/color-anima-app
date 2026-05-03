import ColorAnimaAppWorkspaceApplication
import SwiftUI

package enum CanvasPreviewRegionBoundaryPathBuilder {
    package static func resetCacheForTesting() {
        imageSpacePathCache.reset()
    }

    package static func imageSpaceBuildCountForTesting(
        for region: CanvasSelectionRegion,
        imageSize: CGSize
    ) -> Int {
        imageSpacePathCache.buildCount(
            for: ImageSpacePathCache.Key(region: region, imageSize: imageSize)
        )
    }

    package static func buildPath(
        for region: CanvasSelectionRegion,
        imageSize: CGSize,
        displayRect: CGRect
    ) -> Path {
        let imageSpacePath = buildImageSpacePath(
            for: region,
            imageSize: imageSize
        )
        return projectPath(
            imageSpacePath,
            imageSize: imageSize,
            displayRect: displayRect
        )
    }

    package static func buildImageSpacePath(
        for region: CanvasSelectionRegion,
        imageSize: CGSize
    ) -> Path {
        let cacheKey = ImageSpacePathCache.Key(region: region, imageSize: imageSize)
        if let cached = imageSpacePathCache.path(for: cacheKey) {
            return cached
        }

        let width = Int(imageSize.width.rounded())
        let height = Int(imageSize.height.rounded())
        guard width > 0, height > 0, imageSize.width > 0, imageSize.height > 0, !region.pixels.isEmpty else {
            return Path()
        }
        let pixelSet = region.pixels
        let widthU = UInt32(width)

        var horizontalEdges: [(y: Int32, x1: Int32, x2: Int32)] = []
        var verticalEdges: [(x: Int32, y1: Int32, y2: Int32)] = []

        for pixel in region.sortedPixels {
            let index = Int(pixel)
            let col = Int32(index % width)
            let row = Int32(index / width)

            if row == 0 || !pixelSet.contains(pixel &- widthU) {
                horizontalEdges.append((y: row, x1: col, x2: col + 1))
            }
            if row == Int32(height - 1) || !pixelSet.contains(pixel &+ widthU) {
                horizontalEdges.append((y: row + 1, x1: col, x2: col + 1))
            }
            if col == 0 || !pixelSet.contains(pixel &- 1) {
                verticalEdges.append((x: col, y1: row, y2: row + 1))
            }
            if col == Int32(width - 1) || !pixelSet.contains(pixel &+ 1) {
                verticalEdges.append((x: col + 1, y1: row, y2: row + 1))
            }
        }

        horizontalEdges.sort { $0.y < $1.y || ($0.y == $1.y && $0.x1 < $1.x1) }
        var mergedHorizontal: [(y: Int32, x1: Int32, x2: Int32)] = []
        for edge in horizontalEdges {
            if let last = mergedHorizontal.last, last.y == edge.y, last.x2 == edge.x1 {
                mergedHorizontal[mergedHorizontal.count - 1].x2 = edge.x2
            } else {
                mergedHorizontal.append(edge)
            }
        }

        verticalEdges.sort { $0.x < $1.x || ($0.x == $1.x && $0.y1 < $1.y1) }
        var mergedVertical: [(x: Int32, y1: Int32, y2: Int32)] = []
        for edge in verticalEdges {
            if let last = mergedVertical.last, last.x == edge.x, last.y2 == edge.y1 {
                mergedVertical[mergedVertical.count - 1].y2 = edge.y2
            } else {
                mergedVertical.append(edge)
            }
        }

        var path = Path()

        for edge in mergedHorizontal {
            path.move(to: CGPoint(x: CGFloat(edge.x1), y: CGFloat(edge.y)))
            path.addLine(to: CGPoint(x: CGFloat(edge.x2), y: CGFloat(edge.y)))
        }
        for edge in mergedVertical {
            path.move(to: CGPoint(x: CGFloat(edge.x), y: CGFloat(edge.y1)))
            path.addLine(to: CGPoint(x: CGFloat(edge.x), y: CGFloat(edge.y2)))
        }

        imageSpacePathCache.store(path, for: cacheKey)
        return path
    }

    package static func projectPath(
        _ imageSpacePath: Path,
        imageSize: CGSize,
        displayRect: CGRect
    ) -> Path {
        guard imageSpacePath.isEmpty == false else { return imageSpacePath }

        let transform = projectionTransform(
            imageSize: imageSize,
            displayRect: displayRect
        )
        return imageSpacePath.applying(transform)
    }

    private static func projectionTransform(
        imageSize: CGSize,
        displayRect: CGRect
    ) -> CGAffineTransform {
        let sx = imageSize.width > 0 ? displayRect.width / imageSize.width : 0
        let sy = imageSize.height > 0 ? displayRect.height / imageSize.height : 0
        return CGAffineTransform(
            a: sx,
            b: 0,
            c: 0,
            d: sy,
            tx: displayRect.minX,
            ty: displayRect.minY
        )
    }
}

private final class ImageSpacePathCache: @unchecked Sendable {
    struct Key: Hashable {
        let regionID: UUID
        let imageWidth: Int
        let imageHeight: Int
        let area: Int
        let boundingBox: CGRect
        let pixelHash: Int

        init(region: CanvasSelectionRegion, imageSize: CGSize) {
            regionID = region.id
            imageWidth = Int(imageSize.width.rounded())
            imageHeight = Int(imageSize.height.rounded())
            area = region.area
            boundingBox = region.boundingBox

            var hasher = Hasher()
            hasher.combine(region.pixels.count)
            for pixel in region.sortedPixels {
                hasher.combine(pixel)
            }
            pixelHash = hasher.finalize()
        }
    }

    private let lock = NSLock()
    private let maxEntryCount = 256
    private var paths: [Key: Path] = [:]
    private var buildCounts: [Key: Int] = [:]
    private var order: [Key] = []

    func path(for key: Key) -> Path? {
        lock.lock()
        defer { lock.unlock() }
        guard let path = paths[key] else { return nil }
        touch(key)
        return path
    }

    func store(_ path: Path, for key: Key) {
        lock.lock()
        defer { lock.unlock() }
        paths[key] = path
        buildCounts[key, default: 0] += 1
        touch(key)
        trimIfNeeded()
    }

    func buildCount(for key: Key) -> Int {
        lock.lock()
        defer { lock.unlock() }
        return buildCounts[key, default: 0]
    }

    func reset() {
        lock.lock()
        defer { lock.unlock() }
        paths.removeAll(keepingCapacity: true)
        buildCounts.removeAll(keepingCapacity: true)
        order.removeAll(keepingCapacity: true)
    }

    private func touch(_ key: Key) {
        if let existingIndex = order.firstIndex(of: key) {
            order.remove(at: existingIndex)
        }
        order.insert(key, at: 0)
    }

    private func trimIfNeeded() {
        while order.count > maxEntryCount {
            let evicted = order.removeLast()
            paths.removeValue(forKey: evicted)
            buildCounts.removeValue(forKey: evicted)
        }
    }
}

private let imageSpacePathCache = ImageSpacePathCache()
