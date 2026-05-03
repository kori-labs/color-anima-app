import ColorAnimaAppWorkspaceApplication
import XCTest

final class RuleWhatIfPreviewStateTests: XCTestCase {
    func testStatePreservesBaselineRuleSetAndSimulationValues() {
        let rule = ColorRule(
            name: "Preview",
            condition: .any,
            color: RGBAColor(red: 0.1, green: 0.2, blue: 0.3)
        )
        let baseline = ColorRuleSet(rules: [rule])
        let simulatedColor = RGBAColor(red: 0.8, green: 0.7, blue: 0.6)

        let state = RuleWhatIfPreviewState(
            baselineRuleSet: baseline,
            simulatedRuleID: rule.id,
            simulatedColor: simulatedColor
        )

        XCTAssertEqual(state.baselineRuleSet, baseline)
        XCTAssertEqual(state.simulatedRuleID, rule.id)
        XCTAssertEqual(state.simulatedColor, simulatedColor)
    }
}
