import ColorAnimaAppWorkspaceApplication
import XCTest

@MainActor
final class CutWorkspaceRenderSettingsCoordinatorTests: XCTestCase {
    func testUpdateRenderSettingsUpdatesStateAndMarksDirty() {
        var state = CutWorkspaceRenderSettingsState()
        XCTAssertEqual(state.renderSettings, .default)
        XCTAssertFalse(state.isDirty)

        let updated = RenderSettingsModel(outputFormat: .png, quality: 0.8, resolutionScale: 2.0)
        CutWorkspaceRenderSettingsCoordinator.update(updated, in: &state)

        XCTAssertEqual(state.renderSettings, updated)
        XCTAssertTrue(state.isDirty)
    }

    func testUpdateRenderSettingsDoesNothingWhenSettingsAreUnchanged() {
        var state = CutWorkspaceRenderSettingsState()
        XCTAssertFalse(state.isDirty)

        CutWorkspaceRenderSettingsCoordinator.update(.default, in: &state)

        XCTAssertEqual(state.renderSettings, .default)
        XCTAssertFalse(state.isDirty)
    }

    func testUpdateRenderSettingsPreservesExistingDirtyStateWhenUnchanged() {
        var state = CutWorkspaceRenderSettingsState(isDirty: true)

        CutWorkspaceRenderSettingsCoordinator.update(.default, in: &state)

        XCTAssertEqual(state.renderSettings, .default)
        XCTAssertTrue(state.isDirty)
    }
}
