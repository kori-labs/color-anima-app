import ColorAnimaAppWorkspaceApplication
import XCTest
@testable import ColorAnimaAppWorkspaceProjectTree

final class ProjectTreeViewStateTests: XCTestCase {
    func testPruneCollapsedNodesRemovesLeavesAndMissingNodes() {
        let tree = makeTree()
        var state = ProjectTreeViewState()
        let orphanID = UUID()
        state.collapsedNodeIDs = [tree.project.id, tree.sequence.id, tree.scene.id, tree.cut.id, orphanID]

        state.pruneCollapsedNodes(in: tree.project)

        XCTAssertEqual(state.collapsedNodeIDs, [tree.project.id, tree.sequence.id, tree.scene.id])
    }

    func testExpandSelectedPathUncollapsesOnlySelectedBranch() {
        let tree = makeTree()
        var state = ProjectTreeViewState()
        state.collapsedNodeIDs = [tree.project.id, tree.sequence.id, tree.scene.id, tree.siblingSequence.id]

        state.expandSelectedPath(
            in: tree.project,
            selectedNodeID: tree.cut.id,
            selectedNodeIDs: [tree.cut.id]
        )

        XCTAssertEqual(state.collapsedNodeIDs, [tree.siblingSequence.id])
    }

    func testBeginDragKeepsSelectionBlockOrFallsBackToSingleNode() {
        let tree = makeTree()
        var state = ProjectTreeViewState()

        state.beginDrag(nodeID: tree.scene.id, selection: [tree.scene.id, tree.childScene.id])
        XCTAssertEqual(state.draggedNodeIDs, [tree.scene.id, tree.childScene.id])

        state.beginDrag(nodeID: tree.cut.id, selection: [])
        XCTAssertEqual(state.draggedNodeIDs, [tree.cut.id])
    }

    func testRenameTransitionsResetStateOnCommitAndCancel() {
        let tree = makeTree()
        var state = ProjectTreeViewState()
        var selectedNodeIDs: [UUID] = []
        var renameEvents: [(UUID, String)] = []

        state.startNodeRename(tree.scene, onSelectNode: { selectedNodeIDs.append($0) })

        XCTAssertEqual(selectedNodeIDs, [tree.scene.id])
        XCTAssertEqual(state.editingNodeID, tree.scene.id)
        XCTAssertEqual(state.editingNodeName, tree.scene.name)

        state.editingNodeName = "  Scene Renamed  "
        state.commitNodeRename(tree.scene.id, onRenameNode: { renameEvents.append(($0, $1)) })

        XCTAssertEqual(renameEvents.count, 1)
        XCTAssertEqual(renameEvents.first?.0, tree.scene.id)
        XCTAssertEqual(renameEvents.first?.1, "Scene Renamed")
        XCTAssertNil(state.editingNodeID)
        XCTAssertEqual(state.editingNodeName, "")

        state.startNodeRename(tree.cut, onSelectNode: { _ in })
        state.editingNodeName = "Will be cleared"
        state.cancelNodeRename()

        XCTAssertNil(state.editingNodeID)
        XCTAssertEqual(state.editingNodeName, "")
    }

    func testSelectionChangeCancelsRenameWhenEditingDifferentNode() {
        let tree = makeTree()
        var state = ProjectTreeViewState()

        state.startNodeRename(tree.sequence, onSelectNode: { _ in })
        state.cancelNodeRenameIfSelectionChanged(
            selectedNodeID: tree.scene.id,
            selectedNodeIDs: [tree.scene.id]
        )

        XCTAssertNil(state.editingNodeID)
        XCTAssertEqual(state.editingNodeName, "")
    }

    func testSelectionChangeKeepsRenameActiveWhenSelectionDoesNotChange() {
        let tree = makeTree()
        var state = ProjectTreeViewState()

        state.startNodeRename(tree.sequence, onSelectNode: { _ in })
        state.cancelNodeRenameIfSelectionChanged(
            selectedNodeID: tree.sequence.id,
            selectedNodeIDs: [tree.sequence.id]
        )

        XCTAssertEqual(state.editingNodeID, tree.sequence.id)
        XCTAssertEqual(state.editingNodeName, tree.sequence.name)
    }

    private func makeTree() -> (
        project: WorkspaceProjectTreeNode,
        sequence: WorkspaceProjectTreeNode,
        scene: WorkspaceProjectTreeNode,
        childScene: WorkspaceProjectTreeNode,
        cut: WorkspaceProjectTreeNode,
        siblingSequence: WorkspaceProjectTreeNode
    ) {
        let cut = WorkspaceProjectTreeNode(id: UUID(), kind: .cut, name: "CUT001")
        let scene = WorkspaceProjectTreeNode(id: UUID(), kind: .scene, name: "SC001", children: [cut])
        let childScene = WorkspaceProjectTreeNode(id: UUID(), kind: .scene, name: "SC002")
        let sequence = WorkspaceProjectTreeNode(id: UUID(), kind: .sequence, name: "SQ001", children: [scene, childScene])
        let siblingSequence = WorkspaceProjectTreeNode(id: UUID(), kind: .sequence, name: "SQ002")
        let project = WorkspaceProjectTreeNode(id: UUID(), kind: .project, name: "Project", children: [sequence, siblingSequence])
        return (project, sequence, scene, childScene, cut, siblingSequence)
    }
}
