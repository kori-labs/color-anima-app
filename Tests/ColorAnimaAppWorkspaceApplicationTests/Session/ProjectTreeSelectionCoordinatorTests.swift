import XCTest
@testable import ColorAnimaAppWorkspaceApplication

final class ProjectTreeSelectionCoordinatorTests: XCTestCase {
    func testPathKeyRangeAndSiblingsFollowTreeStructure() {
        let tree = makeTree()

        let path = ProjectTreeSelectionCoordinator.treeNodePath(
            for: tree.firstCut.id,
            in: tree.project
        )
        let key = ProjectTreeSelectionCoordinator.treeSelectionKey(
            for: tree.firstCut.id,
            in: tree.project
        )
        let siblings = ProjectTreeSelectionCoordinator.siblingNodeIDs(
            for: tree.firstCut.id,
            in: tree.project
        )
        let range = ProjectTreeSelectionCoordinator.selectionRange(
            from: tree.firstCut.id,
            to: tree.secondCut.id,
            in: tree.project
        )

        XCTAssertEqual(path?.map(\.id), [
            tree.project.id,
            tree.sequence.id,
            tree.scene.id,
            tree.firstCut.id
        ])
        XCTAssertEqual(key, ProjectTreeSelectionKey(kind: .cut, parentID: tree.scene.id))
        XCTAssertEqual(siblings, [tree.firstCut.id, tree.secondCut.id])
        XCTAssertEqual(range, [tree.firstCut.id, tree.secondCut.id])
    }

    func testSelectNodePlainActivatesCutAndRequestsWorkspaceLoad() {
        let tree = makeTree()
        let frameID = makeID(20)
        var state = ProjectTreeSelectionState(
            rootNode: tree.project,
            frameSelectionMemory: ProjectFrameSelectionMemoryState(
                workspaces: [
                    tree.firstCut.id: ProjectFrameSelectionMemoryWorkspaceState(
                        frameIDsInDisplayOrder: [frameID],
                        selectedFrameID: frameID,
                        selectedFrameIDs: [frameID],
                        selectedFrameSelectionAnchorID: frameID
                    )
                ]
            )
        )

        ProjectTreeSelectionCoordinator.selectNode(tree.firstCut.id, in: &state)

        XCTAssertEqual(state.selectedNodeID, tree.firstCut.id)
        XCTAssertEqual(state.selectedNodeIDs, [tree.firstCut.id])
        XCTAssertEqual(state.selectionAnchorNodeID, tree.firstCut.id)
        XCTAssertEqual(state.activeCutID, tree.firstCut.id)
        XCTAssertEqual(state.lastOpenedCutID, tree.firstCut.id)
        XCTAssertEqual(state.workspaceLoadRequestCutID, tree.firstCut.id)
        XCTAssertTrue(state.didRequestActiveCutRefresh)
        XCTAssertEqual(state.frameSelectionMemory.selectedFrameIDByCutID[tree.firstCut.id], frameID)
    }

    func testSelectNodeAdditiveTogglesWithinSharedParentAndResetsAcrossKinds() {
        let tree = makeTree()
        var state = ProjectTreeSelectionState(
            rootNode: tree.project,
            selectedNodeID: tree.firstCut.id,
            selectedNodeIDs: [tree.firstCut.id],
            selectionAnchorNodeID: tree.firstCut.id
        )

        ProjectTreeSelectionCoordinator.selectNode(
            tree.secondCut.id,
            modifiers: .additive,
            in: &state
        )

        XCTAssertEqual(state.selectedNodeID, tree.secondCut.id)
        XCTAssertEqual(state.selectedNodeIDs, [tree.firstCut.id, tree.secondCut.id])
        XCTAssertEqual(state.selectionAnchorNodeID, tree.secondCut.id)

        ProjectTreeSelectionCoordinator.selectNode(
            tree.firstCut.id,
            modifiers: .additive,
            in: &state
        )

        XCTAssertEqual(state.selectedNodeID, tree.secondCut.id)
        XCTAssertEqual(state.selectedNodeIDs, [tree.secondCut.id])
        XCTAssertEqual(state.selectionAnchorNodeID, tree.secondCut.id)

        ProjectTreeSelectionCoordinator.selectNode(
            tree.scene.id,
            modifiers: .additive,
            in: &state
        )

        XCTAssertEqual(state.selectedNodeID, tree.scene.id)
        XCTAssertEqual(state.selectedNodeIDs, [tree.scene.id])
        XCTAssertEqual(state.selectionAnchorNodeID, tree.scene.id)
        XCTAssertNil(state.activeCutID)
    }

    func testSelectNodeRangeUsesAnchorWhenNodeSharesParentAndKind() {
        let tree = makeTree()
        var state = ProjectTreeSelectionState(
            rootNode: tree.project,
            selectedNodeID: tree.firstCut.id,
            selectedNodeIDs: [tree.firstCut.id],
            selectionAnchorNodeID: tree.firstCut.id
        )

        ProjectTreeSelectionCoordinator.selectNode(
            tree.secondCut.id,
            modifiers: .range,
            in: &state
        )

        XCTAssertEqual(state.selectedNodeID, tree.secondCut.id)
        XCTAssertEqual(state.selectedNodeIDs, [tree.firstCut.id, tree.secondCut.id])
        XCTAssertEqual(state.selectionAnchorNodeID, tree.firstCut.id)
    }

    func testNormalizeSelectionAfterStructureChangeFallsBackToFirstCut() {
        let oldTree = makeTree()
        let newCut = WorkspaceProjectTreeNode(id: makeID(30), kind: .cut, name: "CUT010")
        let newRoot = WorkspaceProjectTreeNode(
            id: oldTree.project.id,
            kind: .project,
            name: "Project",
            children: [
                WorkspaceProjectTreeNode(
                    id: makeID(31),
                    kind: .sequence,
                    name: "SQ010",
                    children: [
                        WorkspaceProjectTreeNode(
                            id: makeID(32),
                            kind: .scene,
                            name: "SC010",
                            children: [newCut]
                        )
                    ]
                )
            ]
        )
        var state = ProjectTreeSelectionState(
            rootNode: newRoot,
            selectedNodeID: oldTree.firstCut.id,
            selectedNodeIDs: [oldTree.firstCut.id],
            selectionAnchorNodeID: oldTree.firstCut.id
        )

        ProjectTreeSelectionCoordinator.normalizeSelectionAfterStructureChange(in: &state)

        XCTAssertEqual(state.selectedNodeID, newCut.id)
        XCTAssertEqual(state.selectedNodeIDs, [newCut.id])
        XCTAssertEqual(state.selectionAnchorNodeID, newCut.id)
        XCTAssertEqual(state.activeCutID, newCut.id)
        XCTAssertEqual(state.lastOpenedCutID, newCut.id)
    }

    func testPruneStaleCutStateDropsRemovedCutAndRepairsFrameSelectionMemory() {
        let tree = makeTree()
        let retainedRoot = WorkspaceProjectTreeNode(
            id: tree.project.id,
            kind: .project,
            name: "Project",
            children: [
                WorkspaceProjectTreeNode(
                    id: tree.sequence.id,
                    kind: .sequence,
                    name: tree.sequence.name,
                    children: [
                        WorkspaceProjectTreeNode(
                            id: tree.scene.id,
                            kind: .scene,
                            name: tree.scene.name,
                            children: [tree.secondCut]
                        )
                    ]
                )
            ]
        )
        let validFrameID = makeID(40)
        let staleFrameID = makeID(41)
        var state = ProjectTreeSelectionState(
            rootNode: retainedRoot,
            selectedNodeID: tree.firstCut.id,
            selectedNodeIDs: [tree.firstCut.id, tree.secondCut.id],
            selectionAnchorNodeID: tree.firstCut.id,
            activeCutID: tree.firstCut.id,
            lastOpenedCutID: tree.firstCut.id,
            framePlaybackCutID: tree.firstCut.id,
            dirtyCutIDs: [tree.firstCut.id, tree.secondCut.id],
            frameSelectionMemory: ProjectFrameSelectionMemoryState(
                workspaces: [
                    tree.firstCut.id: ProjectFrameSelectionMemoryWorkspaceState(
                        frameIDsInDisplayOrder: [makeID(42)]
                    ),
                    tree.secondCut.id: ProjectFrameSelectionMemoryWorkspaceState(
                        frameIDsInDisplayOrder: [validFrameID],
                        selectedFrameID: validFrameID,
                        selectedFrameIDs: [validFrameID],
                        selectedFrameSelectionAnchorID: validFrameID
                    )
                ],
                selectedFrameIDByCutID: [
                    tree.firstCut.id: makeID(42),
                    tree.secondCut.id: staleFrameID
                ],
                selectedFrameIDsByCutID: [
                    tree.firstCut.id: [makeID(42)],
                    tree.secondCut.id: [validFrameID, staleFrameID]
                ],
                frameSelectionAnchorByCutID: [
                    tree.secondCut.id: staleFrameID
                ],
                selectedFrameSelectionOrderByCutID: [
                    tree.secondCut.id: [staleFrameID, validFrameID]
                ]
            )
        )

        ProjectTreeSelectionCoordinator.pruneStaleCutState(in: &state)

        XCTAssertEqual(state.activeCutID, tree.secondCut.id)
        XCTAssertEqual(state.lastOpenedCutID, tree.secondCut.id)
        XCTAssertEqual(state.selectedNodeID, tree.secondCut.id)
        XCTAssertEqual(state.selectedNodeIDs, [tree.secondCut.id])
        XCTAssertEqual(state.selectionAnchorNodeID, tree.secondCut.id)
        XCTAssertNil(state.framePlaybackCutID)
        XCTAssertTrue(state.didRequestFramePlaybackStop)
        XCTAssertEqual(state.dirtyCutIDs, [tree.secondCut.id])
        XCTAssertNil(state.frameSelectionMemory.workspaces[tree.firstCut.id])
        XCTAssertEqual(state.frameSelectionMemory.selectedFrameIDByCutID[tree.secondCut.id], validFrameID)
        XCTAssertEqual(state.frameSelectionMemory.selectedFrameIDsByCutID[tree.secondCut.id], [validFrameID])
        XCTAssertEqual(state.frameSelectionMemory.frameSelectionAnchorByCutID[tree.secondCut.id], validFrameID)
        XCTAssertEqual(state.frameSelectionMemory.selectedFrameSelectionOrderByCutID[tree.secondCut.id], [validFrameID])
    }

    private func makeTree() -> (
        project: WorkspaceProjectTreeNode,
        sequence: WorkspaceProjectTreeNode,
        scene: WorkspaceProjectTreeNode,
        firstCut: WorkspaceProjectTreeNode,
        secondCut: WorkspaceProjectTreeNode
    ) {
        let firstCut = WorkspaceProjectTreeNode(id: makeID(1), kind: .cut, name: "CUT001")
        let secondCut = WorkspaceProjectTreeNode(id: makeID(2), kind: .cut, name: "CUT002")
        let scene = WorkspaceProjectTreeNode(
            id: makeID(3),
            kind: .scene,
            name: "SC001",
            children: [firstCut, secondCut]
        )
        let sequence = WorkspaceProjectTreeNode(
            id: makeID(4),
            kind: .sequence,
            name: "SQ001",
            children: [scene]
        )
        let project = WorkspaceProjectTreeNode(
            id: makeID(5),
            kind: .project,
            name: "Project",
            children: [sequence]
        )
        return (project, sequence, scene, firstCut, secondCut)
    }

    private func makeID(_ value: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", value))!
    }
}
