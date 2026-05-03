import ColorAnimaAppWorkspaceApplication
import ColorAnimaAppWorkspaceDesignSystem
import SwiftUI

package struct CanvasPreviewSelectionOverlay: View {
    let presentation: CutWorkspaceCanvasPresentation
    let displayRect: CGRect

    package init(presentation: CutWorkspaceCanvasPresentation, displayRect: CGRect) {
        self.presentation = presentation
        self.displayRect = displayRect
    }

    package var body: some View {
        let regions = presentation.selectedRegions
        ForEach(regions, id: \.id) { region in
            SelectionRegionOutline(
                region: region,
                imageSize: presentation.imageSize,
                displayRect: displayRect
            )
        }
    }
}

private struct SelectionRegionOutline: View {
    let region: CanvasSelectionRegion
    let imageSize: CGSize
    let displayRect: CGRect

    @State private var imageSpaceOutlinePath = Path()

    private var outlinePath: Path {
        CanvasPreviewRegionBoundaryPathBuilder.projectPath(
            imageSpaceOutlinePath,
            imageSize: imageSize,
            displayRect: displayRect
        )
    }

    var body: some View {
        ZStack {
            outlinePath
                .stroke(
                    WorkspaceChromeStyle.selectionStroke.opacity(WorkspaceChromeStyle.selectionGlowOpacity),
                    lineWidth: WorkspaceChromeStyle.selectionStrokeWidth + 3
                )
                .blur(radius: 3)
            outlinePath
                .stroke(
                    WorkspaceChromeStyle.selectionStroke,
                    lineWidth: WorkspaceChromeStyle.selectionStrokeWidth
                )
        }
        .allowsHitTesting(false)
        .task(id: SelectionPathTaskID(
            region: region,
            imageSize: imageSize
        )) {
            imageSpaceOutlinePath = CanvasPreviewRegionBoundaryPathBuilder.buildImageSpacePath(
                for: region,
                imageSize: imageSize
            )
        }
    }
}

private struct SelectionPathTaskID: Equatable {
    let regionID: UUID
    let imageSize: CGSize
    let area: Int
    let boundingBox: CGRect
    let firstPixelIndex: Int?
    let middlePixelIndex: Int?
    let lastPixelIndex: Int?

    init(region: CanvasSelectionRegion, imageSize: CGSize) {
        self.regionID = region.id
        self.imageSize = imageSize
        self.area = region.area
        self.boundingBox = region.boundingBox
        let sorted = region.sortedPixels
        self.firstPixelIndex = sorted.first.map(Int.init)
        self.middlePixelIndex = sorted.isEmpty ? nil : Int(sorted[sorted.count / 2])
        self.lastPixelIndex = sorted.last.map(Int.init)
    }
}

package enum CanvasPreviewSelectionOverlayMetrics {
    package static func projectedSelectionRect(
        _ boundingBox: CGRect,
        imageSize: CGSize,
        displayRect: CGRect
    ) -> CGRect {
        CanvasPreviewLayoutMath.projectBoundingBox(
            boundingBox,
            imageSize: imageSize,
            into: displayRect
        )
    }
}
