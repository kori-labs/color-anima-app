import ColorAnimaAppWorkspaceApplication
import XCTest
@testable import ColorAnimaAppWorkspaceProjectTree

@MainActor
final class ProjectTreeActionRulesTests: XCTestCase {
    func testCreateButtonsFollowSelectionKindRules() {
        let tree = makeTree()

        XCTAssertTrue(ProjectTreeActionRules.canCreateSequence(from: tree.project))
        XCTAssertFalse(ProjectTreeActionRules.canCreateSequence(from: tree.sequence))
        XCTAssertFalse(ProjectTreeActionRules.canCreateSequence(from: tree.scene))
        XCTAssertFalse(ProjectTreeActionRules.canCreateSequence(from: tree.cut))

        XCTAssertFalse(ProjectTreeActionRules.canCreateScene(from: tree.project))
        XCTAssertTrue(ProjectTreeActionRules.canCreateScene(from: tree.sequence))
        XCTAssertFalse(ProjectTreeActionRules.canCreateScene(from: tree.scene))
        XCTAssertFalse(ProjectTreeActionRules.canCreateScene(from: tree.cut))

        XCTAssertFalse(ProjectTreeActionRules.canCreateCut(from: tree.project))
        XCTAssertFalse(ProjectTreeActionRules.canCreateCut(from: tree.sequence))
        XCTAssertTrue(ProjectTreeActionRules.canCreateCut(from: tree.scene))
        XCTAssertTrue(ProjectTreeActionRules.canCreateCut(from: tree.cut))
    }

    func testCutCreationTargetResolvesSceneForSceneSelection() {
        let tree = makeTree()

        let targetSceneID = ProjectTreeActionRules.cutCreationTargetSceneID(
            selectedNodeID: tree.scene.id,
            selectedNode: tree.scene,
            rootNode: tree.project
        )

        XCTAssertEqual(targetSceneID, tree.scene.id)
    }

    func testCutCreationTargetResolvesParentSceneForCutSelection() {
        let tree = makeTree()

        let targetSceneID = ProjectTreeActionRules.cutCreationTargetSceneID(
            selectedNodeID: tree.cut.id,
            selectedNode: tree.cut,
            rootNode: tree.project
        )

        XCTAssertEqual(targetSceneID, tree.scene.id)
    }

    func testCutCreationTargetReturnsNilForNonSceneSelections() {
        let tree = makeTree()

        XCTAssertNil(
            ProjectTreeActionRules.cutCreationTargetSceneID(
                selectedNodeID: tree.project.id,
                selectedNode: tree.project,
                rootNode: tree.project
            )
        )

        XCTAssertNil(
            ProjectTreeActionRules.cutCreationTargetSceneID(
                selectedNodeID: tree.sequence.id,
                selectedNode: tree.sequence,
                rootNode: tree.project
            )
        )
    }

    func testPrimaryCreateActionDefaultsToSequenceForProjectSelection() {
        let tree = makeTree()

        let action = ProjectTreeActionRules.primaryCreateAction(
            selectedNodeID: tree.project.id,
            selectedNode: tree.project,
            rootNode: tree.project
        )

        XCTAssertEqual(action.title, "New Sequence")
        XCTAssertEqual(action.kind, .sequence)
        XCTAssertTrue(action.isEnabled)
    }

    func testPrimaryCreateActionUsesSequenceForSceneAndParentSceneForCut() {
        let tree = makeTree()

        let sceneAction = ProjectTreeActionRules.primaryCreateAction(
            selectedNodeID: tree.sequence.id,
            selectedNode: tree.sequence,
            rootNode: tree.project
        )
        XCTAssertEqual(sceneAction.title, "New Scene")
        XCTAssertEqual(sceneAction.kind, .scene(tree.sequence.id))

        let cutAction = ProjectTreeActionRules.primaryCreateAction(
            selectedNodeID: tree.cut.id,
            selectedNode: tree.cut,
            rootNode: tree.project
        )
        XCTAssertEqual(cutAction.title, "New Cut")
        XCTAssertEqual(cutAction.kind, .cut(tree.scene.id))
    }

    func testExperimentalCreateActionsUseSiblingAndChildMappingForSequenceSelection() {
        let tree = makeTree()

        let actions = ProjectTreeActionRules.experimentalCreateActions(
            selectedNodeID: tree.sequence.id,
            selectedNode: tree.sequence,
            rootNode: tree.project
        )

        XCTAssertEqual(actions.outer.kind, .sequence)
        XCTAssertEqual(actions.inner.kind, .scene(tree.sequence.id))
        XCTAssertTrue(actions.isEnabled)
    }

    func testExperimentalCreateActionsUseSiblingAndChildMappingForSceneSelection() {
        let tree = makeTree()

        let actions = ProjectTreeActionRules.experimentalCreateActions(
            selectedNodeID: tree.scene.id,
            selectedNode: tree.scene,
            rootNode: tree.project
        )

        XCTAssertEqual(actions.outer.kind, .scene(tree.sequence.id))
        XCTAssertEqual(actions.inner.kind, .cut(tree.scene.id))
        XCTAssertTrue(actions.isEnabled)
    }

    func testExperimentalCreateActionsUseCutForBothZonesWhenCutIsSelected() {
        let tree = makeTree()

        let actions = ProjectTreeActionRules.experimentalCreateActions(
            selectedNodeID: tree.cut.id,
            selectedNode: tree.cut,
            rootNode: tree.project
        )

        XCTAssertEqual(actions.outer.kind, .cut(tree.scene.id))
        XCTAssertEqual(actions.inner.kind, .cut(tree.scene.id))
        XCTAssertTrue(actions.isEnabled)
    }

    func testExperimentalCreateActionsDisableBothZonesForProjectSelection() {
        let tree = makeTree()

        let actions = ProjectTreeActionRules.experimentalCreateActions(
            selectedNodeID: tree.project.id,
            selectedNode: tree.project,
            rootNode: tree.project
        )

        XCTAssertEqual(actions.outer.kind, .disabled)
        XCTAssertEqual(actions.inner.kind, .disabled)
        XCTAssertFalse(actions.isEnabled)
    }

    func testTreeHierarchyMetricsIncreaseGutterWidthPerDepth() {
        XCTAssertEqual(ProjectTreeHierarchyMetrics.gutterWidth(for: 0), 0)
        XCTAssertEqual(ProjectTreeHierarchyMetrics.gutterWidth(for: 1), 22)
        XCTAssertEqual(ProjectTreeHierarchyMetrics.gutterWidth(for: 2), 44)
        XCTAssertEqual(ProjectTreeHierarchyMetrics.trunkX(forParentDepth: 0), 14)
        XCTAssertEqual(ProjectTreeHierarchyMetrics.trunkX(forParentDepth: 1), 36)
    }

    func testTreeHierarchyMetricsPropagateAncestorContinuationColumns() {
        XCTAssertEqual(
            ProjectTreeHierarchyMetrics.childContinuationColumns(
                ancestorContinuationColumns: [],
                isCurrentNodeLastSibling: false
            ),
            [true]
        )
        XCTAssertEqual(
            ProjectTreeHierarchyMetrics.childContinuationColumns(
                ancestorContinuationColumns: [true],
                isCurrentNodeLastSibling: true
            ),
            [true, false]
        )
    }

    func testSelectionRangeRequiresSharedParentAndKind() {
        let tree = makeSiblingTree()

        XCTAssertEqual(
            ProjectTreeActionRules.selectionRange(
                from: tree.sequence.id,
                to: tree.siblingSequence.id,
                in: tree.project
            ),
            [tree.sequence.id, tree.siblingSequence.id]
        )

        XCTAssertNil(
            ProjectTreeActionRules.selectionRange(
                from: tree.scene.id,
                to: tree.siblingScene.id,
                in: tree.project
            )
        )
    }

    func testCanMoveSelectionRejectsMixedKindsAndDifferentParents() {
        let tree = makeSiblingTree()

        XCTAssertFalse(
            ProjectTreeActionRules.canMoveSelection(
                [tree.scene.id, tree.siblingCut.id],
                to: tree.sequence.id,
                position: .append,
                in: tree.project
            )
        )

        XCTAssertFalse(
            ProjectTreeActionRules.canMoveSelection(
                [tree.cut.id, tree.siblingCut.id],
                to: tree.siblingSequence.id,
                position: .before,
                in: tree.project
            )
        )

        XCTAssertTrue(
            ProjectTreeActionRules.canMoveSelection(
                [tree.scene.id, tree.childScene.id],
                to: tree.sequence.id,
                position: .append,
                in: tree.project
            )
        )
    }

    func testCanMoveSelectionDisallowsAppendOnSameKindRows() {
        let tree = makeSiblingTree()

        XCTAssertFalse(
            ProjectTreeActionRules.canMoveSelection(
                [tree.cut.id],
                to: tree.siblingCut.id,
                position: .append,
                in: tree.project
            )
        )

        XCTAssertFalse(
            ProjectTreeActionRules.canMoveSelection(
                [tree.scene.id],
                to: tree.childScene.id,
                position: .append,
                in: tree.project
            )
        )

        XCTAssertFalse(
            ProjectTreeActionRules.canMoveSelection(
                [tree.sequence.id],
                to: tree.siblingSequence.id,
                position: .append,
                in: tree.project
            )
        )
    }

    private func makeTree() -> (project: WorkspaceProjectTreeNode, sequence: WorkspaceProjectTreeNode, scene: WorkspaceProjectTreeNode, cut: WorkspaceProjectTreeNode) {
        let cut = WorkspaceProjectTreeNode(id: UUID(), kind: .cut, name: "CUT001")
        let scene = WorkspaceProjectTreeNode(id: UUID(), kind: .scene, name: "SC001", children: [cut])
        let sequence = WorkspaceProjectTreeNode(id: UUID(), kind: .sequence, name: "SQ001", children: [scene])
        let project = WorkspaceProjectTreeNode(id: UUID(), kind: .project, name: "Project", children: [sequence])
        return (project, sequence, scene, cut)
    }

    private func makeSiblingTree() -> (
        project: WorkspaceProjectTreeNode,
        sequence: WorkspaceProjectTreeNode,
        siblingSequence: WorkspaceProjectTreeNode,
        scene: WorkspaceProjectTreeNode,
        siblingScene: WorkspaceProjectTreeNode,
        cut: WorkspaceProjectTreeNode,
        siblingCut: WorkspaceProjectTreeNode,
        childScene: WorkspaceProjectTreeNode
    ) {
        let cut = WorkspaceProjectTreeNode(id: UUID(), kind: .cut, name: "CUT001")
        let siblingCut = WorkspaceProjectTreeNode(id: UUID(), kind: .cut, name: "CUT002")
        let scene = WorkspaceProjectTreeNode(id: UUID(), kind: .scene, name: "SC001", children: [cut])
        let siblingScene = WorkspaceProjectTreeNode(id: UUID(), kind: .scene, name: "SC002", children: [siblingCut])
        let childScene = WorkspaceProjectTreeNode(id: UUID(), kind: .scene, name: "SC003")
        let sequence = WorkspaceProjectTreeNode(id: UUID(), kind: .sequence, name: "SQ001", children: [scene, childScene])
        let siblingSequence = WorkspaceProjectTreeNode(id: UUID(), kind: .sequence, name: "SQ002", children: [siblingScene])
        let project = WorkspaceProjectTreeNode(id: UUID(), kind: .project, name: "Project", children: [sequence, siblingSequence])
        return (project, sequence, siblingSequence, scene, siblingScene, cut, siblingCut, childScene)
    }
}
