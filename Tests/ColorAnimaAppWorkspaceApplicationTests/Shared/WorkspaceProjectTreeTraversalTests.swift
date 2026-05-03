import XCTest
@testable import ColorAnimaAppWorkspaceApplication

final class WorkspaceProjectTreeTraversalTests: XCTestCase {
    func testFirstCutIDReturnsFirstCutInTreeOrder() {
        let firstCutID = UUID()
        let secondCutID = UUID()
        let root = makeTree(firstCutID: firstCutID, secondCutID: secondCutID)

        XCTAssertEqual(root.firstCutID, firstCutID)
    }

    func testAllCutIDsReturnsCutIDsInTreeOrder() {
        let firstCutID = UUID()
        let secondCutID = UUID()
        let root = makeTree(firstCutID: firstCutID, secondCutID: secondCutID)

        XCTAssertEqual(root.allCutIDs, [firstCutID, secondCutID])
    }

    func testTraversalReturnsEmptyWhenTreeHasNoCuts() {
        let root = WorkspaceProjectTreeNode(
            id: UUID(),
            kind: .project,
            name: "Project",
            children: [
                WorkspaceProjectTreeNode(id: UUID(), kind: .sequence, name: "SQ001"),
            ]
        )

        XCTAssertNil(root.firstCutID)
        XCTAssertTrue(root.allCutIDs.isEmpty)
    }

    func testCutNodeUsesOwnID() {
        let cutID = UUID()
        let cut = WorkspaceProjectTreeNode(id: cutID, kind: .cut, name: "CUT001")

        XCTAssertEqual(cut.firstCutID, cutID)
        XCTAssertEqual(cut.allCutIDs, [cutID])
    }

    private func makeTree(firstCutID: UUID, secondCutID: UUID) -> WorkspaceProjectTreeNode {
        let firstCut = WorkspaceProjectTreeNode(id: firstCutID, kind: .cut, name: "CUT001")
        let secondCut = WorkspaceProjectTreeNode(id: secondCutID, kind: .cut, name: "CUT002")
        let firstScene = WorkspaceProjectTreeNode(
            id: UUID(),
            kind: .scene,
            name: "SC001",
            children: [firstCut]
        )
        let secondScene = WorkspaceProjectTreeNode(
            id: UUID(),
            kind: .scene,
            name: "SC002",
            children: [secondCut]
        )
        return WorkspaceProjectTreeNode(
            id: UUID(),
            kind: .project,
            name: "Project",
            children: [
                WorkspaceProjectTreeNode(id: UUID(), kind: .sequence, name: "SQ001", children: [firstScene]),
                WorkspaceProjectTreeNode(id: UUID(), kind: .sequence, name: "SQ002", children: [secondScene]),
            ]
        )
    }
}
