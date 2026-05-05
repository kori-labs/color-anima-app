import ColorAnimaAppWorkspaceApplication
import ColorAnimaAppWorkspaceDesignSystem
import SwiftUI

package struct CanvasPreviewDropTargetOverlay: View {
    let region: CanvasSelectionRegion?
    let imageSize: CGSize
    let displayRect: CGRect
    let regionColor: Color?

    @State private var outlinePath = Path()

    package init(
        region: CanvasSelectionRegion?,
        imageSize: CGSize,
        displayRect: CGRect,
        regionColor: Color? = nil
    ) {
        self.region = region
        self.imageSize = imageSize
        self.displayRect = displayRect
        self.regionColor = regionColor
    }

    package var body: some View {
        if region != nil {
            let overlayColor = regionColor ?? Color.accentColor

            TimelineView(.animation) { timeline in
                let elapsed = timeline.date.timeIntervalSinceReferenceDate
                let phase = CGFloat(elapsed.truncatingRemainder(dividingBy: 0.5)) / 0.5 * 14
                ZStack {
                    outlinePath
                        .stroke(
                            overlayColor.opacity(WorkspaceFoundation.Metrics.badgeTintOpacity),
                            style: StrokeStyle(lineWidth: 6, dash: [8, 6], dashPhase: phase)
                        )
                        .blur(radius: 4)
                    outlinePath
                        .stroke(
                            overlayColor,
                            style: StrokeStyle(lineWidth: 1.5, dash: [8, 6], dashPhase: phase)
                        )
                }
                .allowsHitTesting(false)
            }
            .task(id: PathTaskID(
                regionID: region?.id,
                displaySize: displayRect.size,
                imageSize: imageSize
            )) {
                if let region {
                    outlinePath = CanvasPreviewRegionBoundaryPathBuilder.buildPath(
                        for: region,
                        imageSize: imageSize,
                        displayRect: displayRect
                    )
                } else {
                    outlinePath = Path()
                }
            }
        }
    }

    private struct PathTaskID: Equatable {
        let regionID: UUID?
        let displaySize: CGSize
        let imageSize: CGSize
    }
}
