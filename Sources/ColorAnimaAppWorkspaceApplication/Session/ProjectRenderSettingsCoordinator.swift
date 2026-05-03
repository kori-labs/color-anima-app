import Foundation

public struct ProjectRenderSettingsWorkspaceState: Equatable, Sendable {
    public var renderSettings: CutWorkspaceRenderSettingsState

    public init(renderSettings: CutWorkspaceRenderSettingsState = CutWorkspaceRenderSettingsState()) {
        self.renderSettings = renderSettings
    }
}

public struct ProjectRenderSettingsState: Equatable, Sendable {
    public var activeCutID: UUID?
    public var workspaces: [UUID: ProjectRenderSettingsWorkspaceState]

    public init(
        activeCutID: UUID? = nil,
        workspaces: [UUID: ProjectRenderSettingsWorkspaceState] = [:]
    ) {
        self.activeCutID = activeCutID
        self.workspaces = workspaces
    }
}

@MainActor
public enum ProjectRenderSettingsCoordinator {
    @discardableResult
    public static func updateRenderSettings(
        _ settings: RenderSettingsModel,
        in state: inout ProjectRenderSettingsState
    ) -> Bool {
        guard let activeCutID = state.activeCutID,
              var workspace = state.workspaces[activeCutID] else {
            return false
        }

        let previousWorkspace = workspace
        CutWorkspaceRenderSettingsCoordinator.update(settings, in: &workspace.renderSettings)
        guard workspace != previousWorkspace else { return false }

        state.workspaces[activeCutID] = workspace
        return true
    }
}
