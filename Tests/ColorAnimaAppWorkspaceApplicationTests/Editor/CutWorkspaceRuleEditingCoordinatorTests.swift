import XCTest
@testable import ColorAnimaAppWorkspaceApplication

final class CutWorkspaceRuleEditingCoordinatorTests: XCTestCase {
    func testAddRuleIncreasesRuleCount() {
        var state = CutWorkspaceRuleEditingState()
        let initialCount = state.colorRuleSet.rules.count

        CutWorkspaceRuleEditingCoordinator.addRule(makeRule(), in: &state)

        XCTAssertEqual(state.colorRuleSet.rules.count, initialCount + 1)
    }

    func testRemoveRuleDeletesMatchingRule() {
        let rule = makeRule()
        var state = CutWorkspaceRuleEditingState(colorRuleSet: ColorRuleSet(rules: [rule]))

        let removed = CutWorkspaceRuleEditingCoordinator.removeRule(id: rule.id, in: &state)

        XCTAssertTrue(removed)
        XCTAssertTrue(state.colorRuleSet.rules.isEmpty)
    }

    func testMoveRuleSwapsPriority() {
        let ruleA = makeRule(name: "Rule A")
        let ruleB = makeRule(name: "Rule B")
        var state = CutWorkspaceRuleEditingState(colorRuleSet: ColorRuleSet(rules: [ruleA, ruleB]))

        let moved = CutWorkspaceRuleEditingCoordinator.moveRule(
            fromOffsets: IndexSet(integer: 0),
            toOffset: 2,
            in: &state
        )

        XCTAssertTrue(moved)
        XCTAssertEqual(state.colorRuleSet.rules.map(\.id), [ruleB.id, ruleA.id])
    }

    func testUpdateRuleReplacesMatchingRule() {
        let rule = makeRule(name: "Original")
        let updated = ColorRule(
            id: rule.id,
            name: "Updated",
            condition: .backgroundCandidate,
            color: .black,
            isEnabled: false
        )
        var state = CutWorkspaceRuleEditingState(colorRuleSet: ColorRuleSet(rules: [rule]))

        let didUpdate = CutWorkspaceRuleEditingCoordinator.updateRule(updated, in: &state)

        XCTAssertTrue(didUpdate)
        XCTAssertEqual(state.colorRuleSet.rules, [updated])
    }

    func testTriggerWhatIfPreviewCapturesBaselineRuleSet() {
        let rule = makeRule()
        var state = CutWorkspaceRuleEditingState(colorRuleSet: ColorRuleSet(rules: [rule]))
        let simulatedColor = RGBAColor(red: 0.0, green: 0.0, blue: 1.0)

        CutWorkspaceRuleEditingCoordinator.triggerWhatIfPreview(
            ruleID: rule.id,
            simulatedColor: simulatedColor,
            in: &state
        )

        XCTAssertEqual(state.activeWhatIfPreviewState?.baselineRuleSet, ColorRuleSet(rules: [rule]))
        XCTAssertEqual(state.activeWhatIfPreviewState?.simulatedRuleID, rule.id)
        XCTAssertEqual(state.activeWhatIfPreviewState?.simulatedColor, simulatedColor)
    }

    func testClearWhatIfPreviewRemovesActivePreview() {
        let rule = makeRule()
        var state = CutWorkspaceRuleEditingState(colorRuleSet: ColorRuleSet(rules: [rule]))
        CutWorkspaceRuleEditingCoordinator.triggerWhatIfPreview(
            ruleID: rule.id,
            simulatedColor: .black,
            in: &state
        )

        CutWorkspaceRuleEditingCoordinator.clearWhatIfPreview(in: &state)

        XCTAssertNil(state.activeWhatIfPreviewState)
    }

    func testInvalidMoveIsIgnored() {
        let rule = makeRule()
        var state = CutWorkspaceRuleEditingState(colorRuleSet: ColorRuleSet(rules: [rule]))

        let moved = CutWorkspaceRuleEditingCoordinator.moveRule(
            fromOffsets: IndexSet(integer: 10),
            toOffset: 0,
            in: &state
        )

        XCTAssertFalse(moved)
        XCTAssertEqual(state.colorRuleSet.rules, [rule])
    }

    private func makeRule(
        name: String = "Test Rule",
        condition: ColorRuleCondition = .any,
        color: RGBAColor = RGBAColor(red: 1.0, green: 0.0, blue: 0.0)
    ) -> ColorRule {
        ColorRule(name: name, condition: condition, color: color)
    }
}
