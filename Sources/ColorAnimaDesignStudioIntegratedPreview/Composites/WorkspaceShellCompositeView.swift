import ColorAnimaAppEngine
import ColorAnimaAppShell
import ColorAnimaAppWorkspace
import SwiftUI

/// Integrated preview: Workspace Shell (engine-linked path).
/// Renders the real WorkspaceShellView with a stub linked WorkspaceState so the
/// full project tree + command bar chrome is visible without a live kernel binary.
struct WorkspaceShellCompositeView: View {
    // approximate: WorkspaceState requires a real AppEngineStatus. Stub a linked
    // state so WorkspaceShellView renders the workspace UI path rather than gating.
    private static let stubState = WorkspaceState(
        engineStatus: AppEngineStatus(
            title: "Engine linked",
            detail: "Kernel v0.0.4 (stub for design preview)",
            kernelLinked: true,
            kernelVersion: nil
        ),
        checkDetail: "Design Studio stub — no live kernel",
        operationalSurfaces: AppShellMetadata.operationalSurfaces
    )

    var body: some View {
        WorkspaceShellView(state: Self.stubState, onRecheck: {})
    }
}
