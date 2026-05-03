import XCTest
@testable import ColorAnimaAppWorkspaceApplication

@MainActor
final class ProjectRenderSettingsCoordinatorTests: XCTestCase {
    func testUpdateRenderSettingsForwardsToActiveWorkspace() {
        let activeCutID = UUID()
        let inactiveCutID = UUID()
        let settings = RenderSettingsModel(outputFormat: .png, quality: 0.8, resolutionScale: 2.0)
        var state = ProjectRenderSettingsState(
            activeCutID: activeCutID,
            workspaces: [
                activeCutID: ProjectRenderSettingsWorkspaceState(),
                inactiveCutID: ProjectRenderSettingsWorkspaceState()
            ]
        )

        let updated = ProjectRenderSettingsCoordinator.updateRenderSettings(settings, in: &state)

        XCTAssertTrue(updated)
        XCTAssertEqual(state.workspaces[activeCutID]?.renderSettings.renderSettings, settings)
        XCTAssertTrue(state.workspaces[activeCutID]?.renderSettings.isDirty == true)
        XCTAssertEqual(state.workspaces[inactiveCutID]?.renderSettings.renderSettings, .default)
        XCTAssertFalse(state.workspaces[inactiveCutID]?.renderSettings.isDirty == true)
    }

    func testUpdateRenderSettingsIsIgnoredWhenNoActiveWorkspaceExists() {
        let cutID = UUID()
        let settings = RenderSettingsModel(outputFormat: .png, quality: 0.8, resolutionScale: 2.0)
        var state = ProjectRenderSettingsState(
            activeCutID: nil,
            workspaces: [cutID: ProjectRenderSettingsWorkspaceState()]
        )

        let updated = ProjectRenderSettingsCoordinator.updateRenderSettings(settings, in: &state)

        XCTAssertFalse(updated)
        XCTAssertEqual(state.workspaces[cutID]?.renderSettings.renderSettings, .default)
        XCTAssertFalse(state.workspaces[cutID]?.renderSettings.isDirty == true)
    }

    func testUpdateRenderSettingsReturnsFalseWhenSettingsAreUnchanged() {
        let cutID = UUID()
        var state = ProjectRenderSettingsState(
            activeCutID: cutID,
            workspaces: [
                cutID: ProjectRenderSettingsWorkspaceState(
                    renderSettings: CutWorkspaceRenderSettingsState(renderSettings: .default)
                )
            ]
        )

        let updated = ProjectRenderSettingsCoordinator.updateRenderSettings(.default, in: &state)

        XCTAssertFalse(updated)
        XCTAssertEqual(state.workspaces[cutID]?.renderSettings.renderSettings, .default)
        XCTAssertFalse(state.workspaces[cutID]?.renderSettings.isDirty == true)
    }
}
