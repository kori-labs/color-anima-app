import ColorAnimaAppWorkspaceApplication
import XCTest
@testable import ColorAnimaAppWorkspace

final class RegionListAssignmentTextTests: XCTestCase {
    func testAssignedAssignmentTextUsesGroupAndSubsetNames() {
        let assignment = RegionListAssignment.assigned(
            groupName: "character",
            subsetName: "skin"
        )

        XCTAssertEqual(RegionListAssignmentText.string(for: assignment), "character / skin")
    }

    func testUnassignedAssignmentTextUsesFallbackLabel() {
        XCTAssertEqual(RegionListAssignmentText.string(for: .unassigned), "Unassigned")
    }
}
