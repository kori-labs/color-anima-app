public struct CutWorkspaceRenderSettingsState: Equatable, Sendable {
    public var renderSettings: RenderSettingsModel
    public var isDirty: Bool

    public init(
        renderSettings: RenderSettingsModel = .default,
        isDirty: Bool = false
    ) {
        self.renderSettings = renderSettings
        self.isDirty = isDirty
    }
}

@MainActor
public enum CutWorkspaceRenderSettingsCoordinator {
    public static func update(
        _ settings: RenderSettingsModel,
        in state: inout CutWorkspaceRenderSettingsState
    ) {
        guard state.renderSettings != settings else { return }
        state.renderSettings = settings
        state.isDirty = true
    }
}
