import CoreGraphics

enum ProjectTreeHierarchyMetrics {
    static let indentStep: CGFloat = 22
    static let connectorAnchorInset: CGFloat = 14

    static func gutterWidth(for depth: Int) -> CGFloat {
        guard depth > 0 else { return 0 }
        return CGFloat(depth) * indentStep
    }

    static func trunkX(forParentDepth parentDepth: Int) -> CGFloat {
        gutterWidth(for: parentDepth) + connectorAnchorInset
    }

    static func childContinuationColumns(
        ancestorContinuationColumns: [Bool],
        isCurrentNodeLastSibling: Bool
    ) -> [Bool] {
        ancestorContinuationColumns + [!isCurrentNodeLastSibling]
    }
}
