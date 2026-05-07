import Testing
@testable import ColorAnimaAppWorkspace

@Suite("WorkspaceHostModel smoke")
@MainActor
struct WorkspaceHostModelSmokeTests {
    @Test("WorkspaceHostModel initializes with core projections")
    func initializesFromDefaultSession() {
        let host = WorkspaceHostModel()

        #expect(host.projectName == "Color Anima Workspace")
        #expect(host.treeRoot.kind == .project)
        #expect(host.activeCutID != nil)
        #expect(host.selectedNode?.kind == .cut)
        #expect(host.frameStripItems.count == 3)
        #expect(host.groups.isEmpty == false)
    }
}
