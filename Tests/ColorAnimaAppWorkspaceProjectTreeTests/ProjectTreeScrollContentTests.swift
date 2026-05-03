import ColorAnimaAppWorkspaceApplication
import AppKit
import SwiftUI
import XCTest
@testable import ColorAnimaAppWorkspaceProjectTree

@MainActor
final class ProjectTreeScrollContentTests: XCTestCase {
    func testProjectTreeScrollContentRendersDifferentBoundaryStatesForEmptyAndPopulatedRoots() {
        let emptyRoot = WorkspaceProjectTreeNode(id: UUID(), kind: .project, name: "Project")
        let populatedRoot = WorkspaceProjectTreeNode(
            id: UUID(),
            kind: .project,
            name: "Project",
            children: [
                WorkspaceProjectTreeNode(id: UUID(), kind: .sequence, name: "SQ001")
            ]
        )

        let emptyData = renderedPNGData(
            for: makeView(rootNode: emptyRoot)
        )
        let populatedData = renderedPNGData(
            for: makeView(rootNode: populatedRoot)
        )

        XCTAssertNotNil(emptyData)
        XCTAssertNotNil(populatedData)
        XCTAssertNotEqual(emptyData, populatedData)
    }

    func testProjectTreeScrollContentRendersDifferentSelectedAndUnselectedPopulatedTrees() {
        let cut = WorkspaceProjectTreeNode(id: UUID(), kind: .cut, name: "CUT001")
        let scene = WorkspaceProjectTreeNode(id: UUID(), kind: .scene, name: "SC001", children: [cut])
        let sequence = WorkspaceProjectTreeNode(id: UUID(), kind: .sequence, name: "SQ001", children: [scene])
        let populatedRoot = WorkspaceProjectTreeNode(
            id: UUID(),
            kind: .project,
            name: "Project",
            children: [sequence]
        )

        let unselectedData = renderedPNGData(
            for: makeView(rootNode: populatedRoot)
        )
        let selectedData = renderedPNGData(
            for: makeView(
                rootNode: populatedRoot,
                selectedNodeID: cut.id,
                selectedNodeIDs: [cut.id],
                selectionAnchorNodeID: cut.id
            )
        )

        XCTAssertNotNil(unselectedData)
        XCTAssertNotNil(selectedData)
        XCTAssertNotEqual(unselectedData, selectedData)
    }

    private func makeView(
        rootNode: WorkspaceProjectTreeNode,
        selectedNodeID: UUID? = nil,
        selectedNodeIDs: Set<UUID> = [],
        selectionAnchorNodeID: UUID? = nil
    ) -> AnyView {
        AnyView(
            ProjectTreeScrollContent(
                rootNode: rootNode,
                selectedNodeID: selectedNodeID,
                selectedNodeIDs: selectedNodeIDs,
                selectionAnchorNodeID: selectionAnchorNodeID,
                onSelectNode: { _, _ in },
                onMoveTreeNodes: { _, _, _ in },
                onDeleteNode: { _ in },
                onStartRename: { _ in },
                onCommitRename: { _ in },
                onCancelRename: {},
                editingNodeID: .constant(nil),
                editingNodeName: .constant(""),
                collapsedNodeIDs: .constant([]),
                draggedNodeIDs: .constant([]),
                dropTargetNodeID: .constant(nil),
                dropTargetPosition: .constant(nil)
            )
            .frame(width: 360, height: 240, alignment: .topLeading)
        )
    }

    private func renderedPNGData<V: View>(for view: V) -> Data? {
        let host = NSHostingView(rootView: view)
        host.frame = NSRect(x: 0, y: 0, width: 360, height: 240)

        let window = NSWindow(
            contentRect: host.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = host
        host.layoutSubtreeIfNeeded()

        guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else {
            return nil
        }
        host.cacheDisplay(in: host.bounds, to: bitmap)
        return bitmap.representation(using: .png, properties: [:])
    }
}
