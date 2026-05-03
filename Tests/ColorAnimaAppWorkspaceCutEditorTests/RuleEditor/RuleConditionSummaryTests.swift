import ColorAnimaAppWorkspaceApplication
import XCTest
@testable import ColorAnimaAppWorkspaceCutEditor

final class RuleConditionSummaryTests: XCTestCase {
    func testConditionSummaryFormatsCatchAllAndBackgroundRules() {
        XCTAssertEqual(RuleConditionSummary.text(for: .any), "Any")
        XCTAssertEqual(RuleConditionSummary.text(for: .backgroundCandidate), "Background")
    }

    func testConditionSummaryFormatsRegionIDPrefix() {
        let id = UUID(uuidString: "12345678-1234-1234-1234-123456789ABC")!

        XCTAssertEqual(RuleConditionSummary.text(for: .regionID(id)), "Region: 12345678")
    }

    func testConditionSummaryFormatsLabelPrefix() {
        XCTAssertEqual(RuleConditionSummary.text(for: .regionLabel("hair")), "Label: hair")
    }
}
