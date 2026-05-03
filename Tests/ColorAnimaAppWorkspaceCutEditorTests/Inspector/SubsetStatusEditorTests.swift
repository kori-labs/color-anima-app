import XCTest
@testable import ColorAnimaAppWorkspaceCutEditor

final class SubsetStatusEditorTests: XCTestCase {
    func testEditorModelFallsBackToFirstStatusWhenActiveStatusIsMissing() {
        let model = SubsetStatusEditorModel(
            activeStatusName: "missing",
            selectedStatusNames: ["default", "night"]
        )

        XCTAssertEqual(model.resolvedActiveStatusName, "default")
    }

    func testEditorModelBlocksRemovingLastRemainingStatus() {
        let model = SubsetStatusEditorModel(
            activeStatusName: "default",
            selectedStatusNames: ["default"]
        )

        XCTAssertFalse(model.canRemoveActiveStatus)
    }

    func testEditorModelAllowsRemovingWhenMultipleStatusesExist() {
        let model = SubsetStatusEditorModel(
            activeStatusName: "night",
            selectedStatusNames: ["default", "night"]
        )

        XCTAssertTrue(model.canRemoveActiveStatus)
        XCTAssertEqual(model.resolvedActiveStatusName, "night")
    }
}
