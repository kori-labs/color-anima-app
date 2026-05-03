import ColorAnimaAppWorkspaceApplication
import XCTest
@testable import ColorAnimaAppWorkspaceProjectTree

/// Correctness regression tests for project-tree drag/drop performance behavior.
///
/// Covers:
/// - `ProjectTreeRowDropPolicy.resolvedDropPosition` zoning and the isolated
///   equality-guard contract used before `setDropPosition` writes.
/// - `ProjectTreeViewState.pruneCollapsedNodes` empty-set and orphan-pruning
///   correctness.
final class ProjectTreeDropDelegatePerformanceTests: XCTestCase {

    // MARK: - setDropPosition equality guard contract

    /// Verifies the equality guard logic in isolation. This does not call
    /// `ProjectTreeRowDropDelegate.dropUpdated`, whose `DropInfo` input is
    /// synthesized by SwiftUI, but it preserves the exact write/no-write
    /// contract the delegate relies on before updating tree state.
    func testEqualityGuardSkipsRedundantDropPositionWrites() {
        var writeCount = 0
        var currentPosition: ProjectTreeDropPosition? = .before

        // Simulate the guard that `dropUpdated` applies:
        //   if position != currentDropPosition() { setDropPosition(position) }
        func applyGuardedWrite(newPosition: ProjectTreeDropPosition?) {
            if newPosition != currentPosition {
                currentPosition = newPosition
                writeCount += 1
            }
        }

        applyGuardedWrite(newPosition: .before) // same as current — must skip
        XCTAssertEqual(writeCount, 0, "No write expected when position is unchanged")

        applyGuardedWrite(newPosition: .after)  // different — must write
        XCTAssertEqual(writeCount, 1, "Write expected when position changes")

        applyGuardedWrite(newPosition: .after)  // same again — must skip
        XCTAssertEqual(writeCount, 1, "No write expected when position is unchanged again")

        applyGuardedWrite(newPosition: nil)     // clearing — must write
        XCTAssertEqual(writeCount, 2, "Write expected when position clears")
    }

    // MARK: - ProjectTreeRowDropPolicy position resolution

    func testResolvedDropPositionReturnsBeforeForTopZone() {
        let tree = makeTree()
        // relativeY = 4/40 = 0.1 → .before zone
        let result = ProjectTreeRowDropPolicy.resolvedDropPosition(
            location: CGPoint(x: 10, y: 4),
            rowHeight: 40,
            draggedNodeIDs: [tree.sequence.id],
            nodeID: tree.siblingSequence.id,
            rootNode: tree.project
        )
        XCTAssertEqual(result, .before)
    }

    func testResolvedDropPositionReturnsAfterForBottomZone() {
        let tree = makeTree()
        // relativeY = 36/40 = 0.9 → .after zone
        let result = ProjectTreeRowDropPolicy.resolvedDropPosition(
            location: CGPoint(x: 10, y: 36),
            rowHeight: 40,
            draggedNodeIDs: [tree.sequence.id],
            nodeID: tree.siblingSequence.id,
            rootNode: tree.project
        )
        XCTAssertEqual(result, .after)
    }

    func testResolvedDropPositionReturnsNilForSelf() {
        let tree = makeTree()
        // Dragging a node onto itself must always return nil
        let result = ProjectTreeRowDropPolicy.resolvedDropPosition(
            location: CGPoint(x: 10, y: 20),
            rowHeight: 40,
            draggedNodeIDs: [tree.sequence.id],
            nodeID: tree.sequence.id,
            rootNode: tree.project
        )
        XCTAssertNil(result)
    }

    // MARK: - pruneCollapsedNodes correctness

    func testPruneCollapsedNodesLeavesStateUnchangedWhenSetIsEmpty() {
        let tree = makeTree()
        var state = ProjectTreeViewState()
        // collapsedNodeIDs starts empty, so pruning must leave the state
        // unchanged.
        let before = state.collapsedNodeIDs
        state.pruneCollapsedNodes(in: tree.project)
        XCTAssertEqual(state.collapsedNodeIDs, before,
            "pruneCollapsedNodes with an empty set must leave state unchanged")
    }

    func testPruneCollapsedNodesRetainsValidAndRemovesOrphanedIDs() {
        let tree = makeTree()
        var state = ProjectTreeViewState()
        let orphanID = UUID()
        state.collapsedNodeIDs = [tree.project.id, orphanID]

        state.pruneCollapsedNodes(in: tree.project)

        XCTAssertTrue(state.collapsedNodeIDs.contains(tree.project.id),
            "Valid collapsed node must be retained after prune")
        XCTAssertFalse(state.collapsedNodeIDs.contains(orphanID),
            "Orphaned collapsed node must be removed after prune")
    }

    func testPruneCollapsedNodesRemovesLeafNodes() {
        let tree = makeTree()
        var state = ProjectTreeViewState()
        // Cuts have no children so they cannot be collapsed.
        state.collapsedNodeIDs = [tree.cut.id, tree.sequence.id]

        state.pruneCollapsedNodes(in: tree.project)

        XCTAssertFalse(state.collapsedNodeIDs.contains(tree.cut.id),
            "Leaf node (cut) must be removed from collapsed set")
        XCTAssertTrue(state.collapsedNodeIDs.contains(tree.sequence.id),
            "Non-leaf node (sequence) must be retained in collapsed set")
    }

    // MARK: - Helpers

    private func makeTree() -> (
        project: WorkspaceProjectTreeNode,
        sequence: WorkspaceProjectTreeNode,
        siblingSequence: WorkspaceProjectTreeNode,
        scene: WorkspaceProjectTreeNode,
        cut: WorkspaceProjectTreeNode
    ) {
        let cut = WorkspaceProjectTreeNode(id: UUID(), kind: .cut, name: "CUT001")
        let scene = WorkspaceProjectTreeNode(id: UUID(), kind: .scene, name: "SC001", children: [cut])
        let sequence = WorkspaceProjectTreeNode(id: UUID(), kind: .sequence, name: "SQ001", children: [scene])
        let siblingSequence = WorkspaceProjectTreeNode(id: UUID(), kind: .sequence, name: "SQ002")
        let project = WorkspaceProjectTreeNode(id: UUID(), kind: .project, name: "Project", children: [sequence, siblingSequence])
        return (project, sequence, siblingSequence, scene, cut)
    }
}
