import ColorAnimaAppWorkspaceApplication
import XCTest
@testable import ColorAnimaAppWorkspaceProjectTree

final class ProjectTreeScrollContentStateTests: XCTestCase {
    func testEmptyRootNodeShowsEmptyStateAndNoRows() {
        let rootNode = WorkspaceProjectTreeNode(id: UUID(), kind: .project, name: "Project")

        let state = ProjectTreeScrollContentState(rootNode: rootNode)

        XCTAssertTrue(state.isEmpty)
        XCTAssertEqual(state.rootRowCount, 0)
    }

    func testPopulatedRootNodeHasRowsAndHidesEmptyState() {
        let child = WorkspaceProjectTreeNode(id: UUID(), kind: .sequence, name: "SQ001")
        let rootNode = WorkspaceProjectTreeNode(id: UUID(), kind: .project, name: "Project", children: [child])

        let state = ProjectTreeScrollContentState(rootNode: rootNode)

        XCTAssertFalse(state.isEmpty)
        XCTAssertEqual(state.rootRowCount, 1)
    }
}
