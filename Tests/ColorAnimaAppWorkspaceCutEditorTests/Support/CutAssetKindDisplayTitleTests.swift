import ColorAnimaAppWorkspaceApplication
import XCTest
@testable import ColorAnimaAppWorkspaceCutEditor

final class CutAssetKindDisplayTitleTests: XCTestCase {
    func testDisplayTitlesMatchWorkspaceLabels() {
        XCTAssertEqual(CutAssetKind.outline.title, "Outline")
        XCTAssertEqual(CutAssetKind.highlightLine.title, "Highlight Line")
        XCTAssertEqual(CutAssetKind.shadowLine.title, "Shadow Line")
    }
}
