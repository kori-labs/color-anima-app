import ColorAnimaAppEngine
import ColorAnimaAppShell

public struct WorkspaceState: Equatable, Sendable {
    public let engineStatus: AppEngineStatus
    public let checkDetail: String
    public let operationalSurfaces: [OperationalSurface]

    public init(
        engineStatus: AppEngineStatus,
        checkDetail: String,
        operationalSurfaces: [OperationalSurface]
    ) {
        self.engineStatus = engineStatus
        self.checkDetail = checkDetail
        self.operationalSurfaces = operationalSurfaces
    }
}

public struct WorkspaceModel: Sendable {
    private let engineClient: AppEngineClient

    public init(engineClient: AppEngineClient = AppEngineClient()) {
        self.engineClient = engineClient
    }

    public func initialState() -> WorkspaceState {
        WorkspaceState(
            engineStatus: engineClient.status,
            checkDetail: "Startup check has not run",
            operationalSurfaces: AppShellMetadata.operationalSurfaces
        )
    }

    public func runStartupCheck() -> WorkspaceState {
        let check = engineClient.runStartupCheck()
        return WorkspaceState(
            engineStatus: check.status,
            checkDetail: check.detail,
            operationalSurfaces: AppShellMetadata.operationalSurfaces
        )
    }
}
