import CoreGraphics
import Foundation

public enum CutWorkspaceRegionHitTesting {
    public static func region(
        at imagePoint: CGPoint,
        imageSize: CGSize,
        in regions: [CanvasSelectionRegion],
        excludingBackgroundCandidates: Bool = false
    ) -> CanvasSelectionRegion? {
        let x = Int(imagePoint.x.rounded(.down))
        let y = Int(imagePoint.y.rounded(.down))

        guard x >= 0,
              y >= 0,
              x < Int(imageSize.width),
              y < Int(imageSize.height)
        else {
            return nil
        }

        let point = CGPoint(x: x, y: y)
        let flatIndex = y * Int(imageSize.width) + x

        return regions.first { region in
            if excludingBackgroundCandidates && region.isBackgroundCandidate {
                return false
            }

            return region.boundingBox.contains(point) && region.contains(pixelIndex: flatIndex)
        }
    }
}
