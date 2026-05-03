import ColorAnimaAppWorkspaceDesignSystem
import SwiftUI

struct TreeConnectorGutter: View {
    let depth: Int
    let isLastSibling: Bool
    let ancestorContinuationColumns: [Bool]

    var body: some View {
        let gutterWidth = ProjectTreeHierarchyMetrics.gutterWidth(for: depth)

        return GeometryReader { proxy in
            Path { path in
                let height = proxy.size.height
                let midY = height / 2

                for (level, continues) in ancestorContinuationColumns.enumerated() where continues {
                    let x = ProjectTreeHierarchyMetrics.trunkX(forParentDepth: level)
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: height))
                }

                guard depth > 0 else { return }

                let currentX = ProjectTreeHierarchyMetrics.trunkX(forParentDepth: depth - 1)
                let horizontalEndX = ProjectTreeHierarchyMetrics.gutterWidth(for: depth)
                path.move(to: CGPoint(x: currentX, y: 0))
                path.addLine(to: CGPoint(x: currentX, y: isLastSibling ? midY : height))
                path.move(to: CGPoint(x: currentX, y: midY))
                path.addLine(to: CGPoint(x: horizontalEndX, y: midY))
            }
            .stroke(
                WorkspaceChromeStyle.Sidebar.connectorStroke,
                style: StrokeStyle(lineWidth: 1.1, lineCap: .round, lineJoin: .round)
            )
        }
        .frame(width: gutterWidth)
    }
}
