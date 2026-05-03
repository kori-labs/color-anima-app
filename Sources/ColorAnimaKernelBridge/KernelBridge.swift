#if canImport(ColorAnimaKernel)
import ColorAnimaKernel
#endif

public struct KernelVersion: Equatable, Sendable, CustomStringConvertible {
    public let major: UInt32
    public let minor: UInt32
    public let patch: UInt32

    public init(major: UInt32, minor: UInt32, patch: UInt32) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    public var description: String {
        "\(major).\(minor).\(patch)"
    }
}

public enum KernelBridgeMode: Equatable, Sendable {
    case linked
    case unavailable
}

public struct KernelBridgeStatus: Equatable, Sendable {
    public let mode: KernelBridgeMode
    public let version: KernelVersion?

    public init(mode: KernelBridgeMode, version: KernelVersion?) {
        self.mode = mode
        self.version = version
    }

    public var isLinked: Bool {
        mode == .linked
    }
}

public struct KernelBridgeSmokeResult: Equatable, Sendable {
    public let status: KernelBridgeStatus
    public let detail: String

    public init(status: KernelBridgeStatus, detail: String) {
        self.status = status
        self.detail = detail
    }
}

public enum KernelBridgeError: Error, Equatable, Sendable {
    case unavailable
}

public struct KernelBridge: Sendable {
    public init() {}

    public var status: KernelBridgeStatus {
        #if canImport(ColorAnimaKernel)
        let version = ca_pipeline_version()
        return KernelBridgeStatus(
            mode: .linked,
            version: KernelVersion(
                major: version.major,
                minor: version.minor,
                patch: version.patch
            )
        )
        #else
        return KernelBridgeStatus(mode: .unavailable, version: nil)
        #endif
    }

    public func runSmokeCheck() -> KernelBridgeSmokeResult {
        let currentStatus = status
        switch currentStatus.mode {
        case .linked:
            let version = currentStatus.version?.description ?? "unknown"
            return KernelBridgeSmokeResult(
                status: currentStatus,
                detail: "ColorAnimaKernel linked, version \(version)"
            )
        case .unavailable:
            return KernelBridgeSmokeResult(
                status: currentStatus,
                detail: "ColorAnimaKernel binary target is not active"
            )
        }
    }

    public func requireLinkedKernel() throws -> KernelBridgeStatus {
        let currentStatus = status
        guard currentStatus.isLinked else {
            throw KernelBridgeError.unavailable
        }
        return currentStatus
    }
}
