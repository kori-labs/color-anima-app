import XCTest
@testable import ColorAnimaAppWorkspaceApplication

final class ProjectRuleEditingCoordinatorTests: XCTestCase {
    func testAddRuleForwardsToActiveWorkspace() {
        let cutID = UUID()
        let inactiveCutID = UUID()
        let rule = makeRule()
        var state = ProjectRuleEditingState(
            activeCutID: cutID,
            workspaces: [
                cutID: ProjectRuleEditingWorkspaceState(),
                inactiveCutID: ProjectRuleEditingWorkspaceState()
            ]
        )

        let added = ProjectRuleEditingCoordinator.addRule(rule, in: &state)

        XCTAssertTrue(added)
        XCTAssertEqual(state.workspaces[cutID]?.ruleEditing.colorRuleSet.rules, [rule])
        XCTAssertEqual(state.workspaces[inactiveCutID]?.ruleEditing.colorRuleSet.rules, [])
    }

    func testRuleEditingIsIgnoredWithoutActiveWorkspace() {
        let cutID = UUID()
        var state = ProjectRuleEditingState(
            activeCutID: nil,
            workspaces: [cutID: ProjectRuleEditingWorkspaceState()]
        )

        let added = ProjectRuleEditingCoordinator.addRule(makeRule(), in: &state)

        XCTAssertFalse(added)
        XCTAssertEqual(state.workspaces[cutID]?.ruleEditing.colorRuleSet.rules, [])
    }

    func testUpdateAndRemoveRuleForwardToActiveWorkspace() {
        let cutID = UUID()
        let rule = makeRule(name: "Original")
        let updated = ColorRule(
            id: rule.id,
            name: "Updated",
            condition: .regionLabel("hair"),
            color: .black
        )
        var state = ProjectRuleEditingState(
            activeCutID: cutID,
            workspaces: [
                cutID: ProjectRuleEditingWorkspaceState(
                    ruleEditing: CutWorkspaceRuleEditingState(
                        colorRuleSet: ColorRuleSet(rules: [rule])
                    )
                )
            ]
        )

        XCTAssertTrue(ProjectRuleEditingCoordinator.updateRule(updated, in: &state))
        XCTAssertEqual(state.workspaces[cutID]?.ruleEditing.colorRuleSet.rules, [updated])

        XCTAssertTrue(ProjectRuleEditingCoordinator.removeRule(id: rule.id, in: &state))
        XCTAssertEqual(state.workspaces[cutID]?.ruleEditing.colorRuleSet.rules, [])
    }

    func testMoveRuleForwardsToActiveWorkspace() {
        let cutID = UUID()
        let ruleA = makeRule(name: "A")
        let ruleB = makeRule(name: "B")
        var state = ProjectRuleEditingState(
            activeCutID: cutID,
            workspaces: [
                cutID: ProjectRuleEditingWorkspaceState(
                    ruleEditing: CutWorkspaceRuleEditingState(
                        colorRuleSet: ColorRuleSet(rules: [ruleA, ruleB])
                    )
                )
            ]
        )

        let moved = ProjectRuleEditingCoordinator.moveRule(
            fromOffsets: IndexSet(integer: 0),
            toOffset: 2,
            in: &state
        )

        XCTAssertTrue(moved)
        XCTAssertEqual(state.workspaces[cutID]?.ruleEditing.colorRuleSet.rules.map(\.id), [ruleB.id, ruleA.id])
    }

    func testWhatIfPreviewForwardsToActiveWorkspace() {
        let cutID = UUID()
        let rule = makeRule()
        var state = ProjectRuleEditingState(
            activeCutID: cutID,
            workspaces: [
                cutID: ProjectRuleEditingWorkspaceState(
                    ruleEditing: CutWorkspaceRuleEditingState(
                        colorRuleSet: ColorRuleSet(rules: [rule])
                    )
                )
            ]
        )

        XCTAssertTrue(
            ProjectRuleEditingCoordinator.triggerWhatIfPreview(
                ruleID: rule.id,
                simulatedColor: .black,
                in: &state
            )
        )
        XCTAssertEqual(state.workspaces[cutID]?.ruleEditing.activeWhatIfPreviewState?.simulatedRuleID, rule.id)

        XCTAssertTrue(ProjectRuleEditingCoordinator.clearWhatIfPreview(in: &state))
        XCTAssertNil(state.workspaces[cutID]?.ruleEditing.activeWhatIfPreviewState)
    }

    private func makeRule(name: String = "Test Rule") -> ColorRule {
        ColorRule(
            name: name,
            condition: .any,
            color: RGBAColor(red: 1.0, green: 0.0, blue: 0.0)
        )
    }
}
