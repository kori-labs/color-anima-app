import ColorAnimaAppEngine
import ColorAnimaKernelBridge
import ColorAnimaAppWorkspace
import XCTest

final class EngineLinkGateTests: XCTestCase {
    func testDestinationUsesWorkspaceShellWhenKernelIsLinked() {
        let state = WorkspaceState(
            engineStatus: AppEngineStatus(
                title: "Engine linked",
                detail: "Kernel binary version 0.0.5",
                kernelLinked: true,
                kernelVersion: KernelVersion(major: 0, minor: 0, patch: 5)
            ),
            checkDetail: "linked",
            operationalSurfaces: []
        )

        XCTAssertEqual(EngineLinkGateDestination.resolve(for: state), .workspaceShell)
    }

    func testDestinationUsesOfflineIntakeWhenKernelIsUnavailable() {
        let state = WorkspaceState(
            engineStatus: AppEngineStatus(
                title: "Engine offline",
                detail: "Build without maintainer kernel artifact",
                kernelLinked: false,
                kernelVersion: nil
            ),
            checkDetail: "offline",
            operationalSurfaces: []
        )

        XCTAssertEqual(EngineLinkGateDestination.resolve(for: state), .offlineIntake)
    }
}
