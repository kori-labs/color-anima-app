import ColorAnimaAppWorkspace
import XCTest

final class WorkspaceModelTests: XCTestCase {
    func testInitialStateCarriesEngineStatusAndSurfaces() {
        let state = WorkspaceModel().initialState()

        XCTAssertFalse(state.engineStatus.title.isEmpty)
        XCTAssertFalse(state.engineStatus.detail.isEmpty)
        XCTAssertFalse(state.checkDetail.isEmpty)
        XCTAssertGreaterThanOrEqual(state.operationalSurfaces.count, 3)
    }

    func testStartupCheckRefreshesWorkspaceState() {
        let state = WorkspaceModel().runStartupCheck()

        XCTAssertFalse(state.engineStatus.title.isEmpty)
        XCTAssertFalse(state.checkDetail.isEmpty)
        XCTAssertEqual(state.engineStatus.kernelLinked, state.engineStatus.kernelVersion != nil)
    }
}
