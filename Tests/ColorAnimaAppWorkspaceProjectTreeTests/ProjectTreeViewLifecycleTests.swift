import AppKit
import ColorAnimaAppWorkspaceApplication
@testable import ColorAnimaAppWorkspaceProjectTree
import SwiftUI
import XCTest

@MainActor
final class ProjectTreeViewLifecycleTests: XCTestCase {
    func testProjectTreeViewWiresAppearAndChangeEventsThroughLifecycle() {
        let tree = makeTree()
        let updatedTree = makeUpdatedTree()
        let spy = ProjectTreeViewLifecycleSpy()
        let host = NSHostingView(
            rootView: makeView(
                rootNode: tree.project,
                selectedNodeID: tree.cut.id,
                selectedNodeIDs: [tree.cut.id],
                selectionAnchorNodeID: tree.cut.id,
                selectedNode: tree.cut,
                lifecycle: spy
            )
        )

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 520),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        pumpMainRunLoop()

        XCTAssertEqual(spy.treeSyncCallCount, 1)
        XCTAssertEqual(spy.selectionSyncCallCount, 0)
        XCTAssertEqual(spy.lastTreeSyncRootNodeID, tree.project.id)
        XCTAssertEqual(spy.lastTreeSyncSelectedNodeID, tree.cut.id)
        XCTAssertEqual(spy.lastTreeSyncSelectedNodeIDs, [tree.cut.id])
        XCTAssertEqual(spy.lastTreeSyncSelectionAnchorNodeID, tree.cut.id)

        host.rootView = makeView(
            rootNode: updatedTree.project,
            selectedNodeID: tree.cut.id,
            selectedNodeIDs: [tree.cut.id],
            selectionAnchorNodeID: tree.cut.id,
            selectedNode: tree.cut,
            lifecycle: spy
        )
        host.layoutSubtreeIfNeeded()
        pumpMainRunLoop()

        XCTAssertEqual(spy.treeSyncCallCount, 2)
        XCTAssertEqual(spy.selectionSyncCallCount, 0)
        XCTAssertEqual(spy.lastTreeSyncRootNodeID, updatedTree.project.id)
        XCTAssertEqual(spy.lastTreeSyncSelectedNodeID, tree.cut.id)
        XCTAssertEqual(spy.lastTreeSyncSelectedNodeIDs, [tree.cut.id])
        XCTAssertEqual(spy.lastTreeSyncSelectionAnchorNodeID, tree.cut.id)

        host.rootView = makeView(
            rootNode: updatedTree.project,
            selectedNodeID: updatedTree.scene.id,
            selectedNodeIDs: [updatedTree.scene.id],
            selectionAnchorNodeID: updatedTree.scene.id,
            selectedNode: updatedTree.scene,
            lifecycle: spy
        )
        host.layoutSubtreeIfNeeded()
        pumpMainRunLoop()

        XCTAssertEqual(spy.treeSyncCallCount, 2)
        XCTAssertEqual(spy.selectionSyncCallCount, 1)
        XCTAssertEqual(spy.lastSelectionSyncRootNodeID, updatedTree.project.id)
        XCTAssertEqual(spy.lastSelectionSyncSelectedNodeID, updatedTree.scene.id)
        XCTAssertEqual(spy.lastSelectionSyncSelectedNodeIDs, [updatedTree.scene.id])
        XCTAssertEqual(spy.lastSelectionSyncSelectionAnchorNodeID, updatedTree.scene.id)
    }

    func testLifecycleSequenceKeepsRenameActiveForUnchangedSelectionAcrossTreeAndSelectionUpdates() {
        let tree = makeTree()
        var state = ProjectTreeViewState()
        state.startNodeRename(tree.sequence, onSelectNode: { _ in })
        state.collapsedNodeIDs = [tree.project.id, tree.sequence.id]

        let lifecycle = ProjectTreeViewLifecycle()
        lifecycle.synchronizeTreeState(
            &state,
            rootNode: tree.project,
            selectedNodeID: tree.sequence.id,
            selectedNodeIDs: [tree.sequence.id],
            selectionAnchorNodeID: tree.sequence.id
        )
        lifecycle.synchronizeSelectionState(
            &state,
            rootNode: tree.project,
            selectedNodeID: tree.sequence.id,
            selectedNodeIDs: [tree.sequence.id],
            selectionAnchorNodeID: tree.sequence.id
        )

        XCTAssertEqual(state.collapsedNodeIDs, [])
        XCTAssertEqual(state.editingNodeID, tree.sequence.id)
        XCTAssertEqual(state.editingNodeName, tree.sequence.name)
    }

    func testSynchronizeTreeStatePrunesAndExpandsSelectedPath() {
        let tree = makeTree()
        var state = ProjectTreeViewState()
        state.collapsedNodeIDs = [tree.project.id, tree.sequence.id, tree.scene.id, tree.cut.id, UUID()]

        let lifecycle = ProjectTreeViewLifecycle()
        lifecycle.synchronizeTreeState(
            &state,
            rootNode: tree.project,
            selectedNodeID: tree.cut.id,
            selectedNodeIDs: [tree.cut.id],
            selectionAnchorNodeID: tree.cut.id
        )

        XCTAssertEqual(state.collapsedNodeIDs, [])
    }

    func testSynchronizeSelectionStateCancelsRenameForDifferentSelection() {
        let tree = makeTree()
        var state = ProjectTreeViewState()
        state.startNodeRename(tree.sequence, onSelectNode: { _ in })
        state.collapsedNodeIDs = [tree.project.id, tree.sequence.id, tree.scene.id]

        let lifecycle = ProjectTreeViewLifecycle()
        lifecycle.synchronizeSelectionState(
            &state,
            rootNode: tree.project,
            selectedNodeID: tree.scene.id,
            selectedNodeIDs: [tree.scene.id],
            selectionAnchorNodeID: tree.scene.id
        )

        XCTAssertEqual(state.collapsedNodeIDs, [])
        XCTAssertNil(state.editingNodeID)
        XCTAssertEqual(state.editingNodeName, "")
    }

    func testCollapsePolicySelectsNodeWhenCollapsingSelectedDescendant() {
        let tree = makeTree()
        var collapsedNodeIDs = Set<UUID>()
        var selectedNodeCall: (id: UUID, modifiers: WorkspaceSelectionModifiers)?

        ProjectTreeCollapsePolicy.toggle(
            node: tree.scene,
            selectedNodeIDs: [tree.cut.id],
            collapsedNodeIDs: &collapsedNodeIDs,
            onSelectNode: { nodeID, modifiers in
                selectedNodeCall = (nodeID, modifiers)
            }
        )

        XCTAssertEqual(collapsedNodeIDs, [tree.scene.id])
        XCTAssertEqual(selectedNodeCall?.id, tree.scene.id)
        XCTAssertEqual(selectedNodeCall?.modifiers, [])
    }

    func testDropPolicyFallsBackFromAppendToAfterForCutReorder() {
        let tree = makeTreeWithSiblingCuts()

        let resolved = ProjectTreeRowDropPolicy.resolvedDropPosition(
            location: CGPoint(x: 0, y: 50),
            rowHeight: 100,
            draggedNodeIDs: [tree.firstCut.id],
            nodeID: tree.secondCut.id,
            rootNode: tree.project
        )

        XCTAssertEqual(resolved, .after)
    }

    func testDropPolicyReturnsNilWhenSelectionContainsTargetNode() {
        let tree = makeTreeWithSiblingCuts()

        let resolved = ProjectTreeRowDropPolicy.resolvedDropPosition(
            location: CGPoint(x: 0, y: 50),
            rowHeight: 100,
            draggedNodeIDs: [tree.secondCut.id],
            nodeID: tree.secondCut.id,
            rootNode: tree.project
        )

        XCTAssertNil(resolved)
    }

    private func makeView(
        rootNode: WorkspaceProjectTreeNode,
        selectedNodeID: UUID?,
        selectedNodeIDs: Set<UUID>,
        selectionAnchorNodeID: UUID?,
        selectedNode: WorkspaceProjectTreeNode?,
        lifecycle: any ProjectTreeViewLifecycleManaging
    ) -> ProjectTreeView {
        ProjectTreeView(
            rootNode: rootNode,
            selectedNodeID: selectedNodeID,
            selectedNodeIDs: selectedNodeIDs,
            selectionAnchorNodeID: selectionAnchorNodeID,
            selectedNode: selectedNode,
            onSelectNode: { _, _ in },
            onMoveTreeNodes: { _, _, _ in },
            onRenameNode: { _, _ in },
            onCreateSequence: {},
            onCreateScene: { _ in },
            onCreateCut: { _ in },
            onOpenProjectSettings: {},
            onDeleteNode: { _ in },
            lifecycle: lifecycle
        )
    }

    private func makeTree() -> (
        project: WorkspaceProjectTreeNode,
        sequence: WorkspaceProjectTreeNode,
        scene: WorkspaceProjectTreeNode,
        cut: WorkspaceProjectTreeNode
    ) {
        let cut = WorkspaceProjectTreeNode(id: UUID(), kind: .cut, name: "CUT001")
        let scene = WorkspaceProjectTreeNode(id: UUID(), kind: .scene, name: "SC001", children: [cut])
        let sequence = WorkspaceProjectTreeNode(id: UUID(), kind: .sequence, name: "SQ001", children: [scene])
        let project = WorkspaceProjectTreeNode(id: UUID(), kind: .project, name: "Project", children: [sequence])
        return (project, sequence, scene, cut)
    }

    private func makeUpdatedTree() -> (
        project: WorkspaceProjectTreeNode,
        sequence: WorkspaceProjectTreeNode,
        scene: WorkspaceProjectTreeNode,
        cut: WorkspaceProjectTreeNode
    ) {
        let cut = WorkspaceProjectTreeNode(id: UUID(), kind: .cut, name: "CUT002")
        let scene = WorkspaceProjectTreeNode(id: UUID(), kind: .scene, name: "SC002", children: [cut])
        let sequence = WorkspaceProjectTreeNode(id: UUID(), kind: .sequence, name: "SQ002", children: [scene])
        let project = WorkspaceProjectTreeNode(id: UUID(), kind: .project, name: "Project Updated", children: [sequence])
        return (project, sequence, scene, cut)
    }

    private func makeTreeWithSiblingCuts() -> (
        project: WorkspaceProjectTreeNode,
        firstCut: WorkspaceProjectTreeNode,
        secondCut: WorkspaceProjectTreeNode
    ) {
        let firstCut = WorkspaceProjectTreeNode(id: UUID(), kind: .cut, name: "CUT001")
        let secondCut = WorkspaceProjectTreeNode(id: UUID(), kind: .cut, name: "CUT002")
        let scene = WorkspaceProjectTreeNode(id: UUID(), kind: .scene, name: "SC001", children: [firstCut, secondCut])
        let sequence = WorkspaceProjectTreeNode(id: UUID(), kind: .sequence, name: "SQ001", children: [scene])
        let project = WorkspaceProjectTreeNode(id: UUID(), kind: .project, name: "Project", children: [sequence])
        return (project, firstCut, secondCut)
    }

    private func pumpMainRunLoop() {
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
    }
}

@MainActor
final class ProjectTreeViewLifecycleSpy: ProjectTreeViewLifecycleManaging {
    private(set) var treeSyncCallCount = 0
    private(set) var selectionSyncCallCount = 0
    private(set) var lastTreeSyncRootNodeID: UUID?
    private(set) var lastTreeSyncSelectedNodeID: UUID?
    private(set) var lastTreeSyncSelectedNodeIDs: Set<UUID> = []
    private(set) var lastTreeSyncSelectionAnchorNodeID: UUID?
    private(set) var lastSelectionSyncRootNodeID: UUID?
    private(set) var lastSelectionSyncSelectedNodeID: UUID?
    private(set) var lastSelectionSyncSelectedNodeIDs: Set<UUID> = []
    private(set) var lastSelectionSyncSelectionAnchorNodeID: UUID?

    func synchronizeTreeState(
        _: inout ProjectTreeViewState,
        rootNode: WorkspaceProjectTreeNode,
        selectedNodeID: UUID?,
        selectedNodeIDs: Set<UUID>,
        selectionAnchorNodeID: UUID?
    ) {
        treeSyncCallCount += 1
        lastTreeSyncRootNodeID = rootNode.id
        lastTreeSyncSelectedNodeID = selectedNodeID
        lastTreeSyncSelectedNodeIDs = selectedNodeIDs
        lastTreeSyncSelectionAnchorNodeID = selectionAnchorNodeID
    }

    func synchronizeSelectionState(
        _: inout ProjectTreeViewState,
        rootNode: WorkspaceProjectTreeNode,
        selectedNodeID: UUID?,
        selectedNodeIDs: Set<UUID>,
        selectionAnchorNodeID: UUID?
    ) {
        selectionSyncCallCount += 1
        lastSelectionSyncRootNodeID = rootNode.id
        lastSelectionSyncSelectedNodeID = selectedNodeID
        lastSelectionSyncSelectedNodeIDs = selectedNodeIDs
        lastSelectionSyncSelectionAnchorNodeID = selectionAnchorNodeID
    }
}
