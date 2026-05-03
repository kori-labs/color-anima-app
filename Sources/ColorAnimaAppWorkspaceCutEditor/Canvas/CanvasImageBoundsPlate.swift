import ColorAnimaAppWorkspaceDesignSystem
import SwiftUI

package struct CanvasImageBoundsPlate: View {
    let tileSize: CGFloat
    let strokeWidth: CGFloat

    package init(tileSize: CGFloat, strokeWidth: CGFloat) {
        self.tileSize = tileSize
        self.strokeWidth = strokeWidth
    }

    package var body: some View {
        Canvas { context, size in
            let rows = Int(ceil(size.height / tileSize))
            let columns = Int(ceil(size.width / tileSize))

            for row in 0..<rows {
                for column in 0..<columns {
                    let tileRect = CGRect(
                        x: CGFloat(column) * tileSize,
                        y: CGFloat(row) * tileSize,
                        width: tileSize,
                        height: tileSize
                    )
                    let color = (row + column).isMultiple(of: 2)
                        ? WorkspaceChromeStyle.checkerboardLight
                        : WorkspaceChromeStyle.checkerboardDark
                    context.fill(Path(tileRect), with: .color(color))
                }
            }
        }
        .overlay {
            Rectangle()
                .strokeBorder(WorkspaceChromeStyle.overlayPanelStroke.opacity(0.9), lineWidth: strokeWidth)
        }
    }
}
