import ColorAnimaKernelBridge

public struct AppEngineStatus: Equatable, Sendable {
    public let title: String
    public let detail: String
    public let kernelLinked: Bool
    public let kernelVersion: KernelVersion?

    public init(
        title: String,
        detail: String,
        kernelLinked: Bool,
        kernelVersion: KernelVersion?
    ) {
        self.title = title
        self.detail = detail
        self.kernelLinked = kernelLinked
        self.kernelVersion = kernelVersion
    }
}

public struct AppEngineStartupCheck: Equatable, Sendable {
    public let status: AppEngineStatus
    public let detail: String

    public init(status: AppEngineStatus, detail: String) {
        self.status = status
        self.detail = detail
    }
}

public struct AppEngineClient: Sendable {
    private let kernelBridge: KernelBridge

    public init(kernelBridge: KernelBridge = KernelBridge()) {
        self.kernelBridge = kernelBridge
    }

    public var status: AppEngineStatus {
        let bridgeStatus = kernelBridge.status
        switch bridgeStatus.mode {
        case .linked:
            let version = bridgeStatus.version?.description ?? "unknown"
            return AppEngineStatus(
                title: "Engine linked",
                detail: "Kernel binary version \(version)",
                kernelLinked: true,
                kernelVersion: bridgeStatus.version
            )
        case .unavailable:
            return AppEngineStatus(
                title: "Engine offline",
                detail: "Build without maintainer kernel artifact",
                kernelLinked: false,
                kernelVersion: nil
            )
        }
    }

    public func runStartupCheck() -> AppEngineStartupCheck {
        let smokeResult = kernelBridge.runSmokeCheck()
        return AppEngineStartupCheck(
            status: status,
            detail: smokeResult.detail
        )
    }
}
