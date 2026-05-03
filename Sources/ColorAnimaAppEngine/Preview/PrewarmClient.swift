// PrewarmClient.swift
// Layer: ColorAnimaAppEngine — public app-side client wrapping the Bridge call.
// Translates between public app DTOs and Bridge DTOs.
// Does NOT import ColorAnimaKernel directly; all kernel access goes via the Bridge.

import ColorAnimaKernelBridge
import Foundation

// MARK: - AppEngine-side DTOs

/// Summary of a prewarm pass for user-visible feedback.
public struct PrewarmApplyReport: Equatable, Sendable {
    /// Number of frames for which preview state was computed.
    public let computedFrameCount: Int
    /// Whether the kernel executed the pass (false when running in stub/unavailable mode).
    public let kernelExecuted: Bool

    public init(computedFrameCount: Int, kernelExecuted: Bool) {
        self.computedFrameCount = computedFrameCount
        self.kernelExecuted = kernelExecuted
    }
}

/// Public frame descriptor used by app-side callers of PrewarmClient.
public struct PrewarmClientFrameInput: Equatable, Sendable {
    public let frameID: UUID
    public let orderIndex: Int

    public init(frameID: UUID, orderIndex: Int) {
        self.frameID = frameID
        self.orderIndex = orderIndex
    }
}

/// Priority tier used by app-side callers of PrewarmClient.
public enum PrewarmClientPriority: Equatable, Sendable {
    /// Highest priority.
    case high
    /// Medium priority.
    case medium
    /// Lowest priority.
    case low
}

/// Parameters for a prewarm pass passed to the client.
public struct PrewarmClientRequest: Equatable, Sendable {
    /// Frames to prewarm (inactive frames only; active frame excluded before this call).
    public let frames: [PrewarmClientFrameInput]
    /// Canvas width in pixels.
    public let canvasWidth: Int
    /// Canvas height in pixels.
    public let canvasHeight: Int
    /// Priority tier for scheduling.
    public let priorityTier: PrewarmClientPriority

    public init(
        frames: [PrewarmClientFrameInput],
        canvasWidth: Int,
        canvasHeight: Int,
        priorityTier: PrewarmClientPriority
    ) {
        self.frames = frames
        self.canvasWidth = canvasWidth
        self.canvasHeight = canvasHeight
        self.priorityTier = priorityTier
    }
}

// MARK: - Client

/// App-side client for the prewarm Bridge.
///
/// Wraps PrewarmBridge and translates between public app DTOs and Bridge DTOs.
/// Callers never interact with Bridge types directly.
///
/// When the kernel binary is not linked (or the C-ABI prewarm function is not
/// yet exposed), run() returns a zero-count report with kernelExecuted = false
/// — allowing callers to fall back to the Swift-only path without crashing.
public struct PrewarmClient: Sendable {
    private let bridge: PrewarmBridge

    public init(bridge: PrewarmBridge = PrewarmBridge()) {
        self.bridge = bridge
    }

    /// Whether the underlying kernel function is available.
    /// Currently always false (stub; see PrewarmBridge.swift for follow-up notes).
    public var isAvailable: Bool {
        bridge.isPrewarmAvailable
    }

    /// Runs a prewarm pass and returns an apply report.
    ///
    /// Returns a zero-count report with kernelExecuted = false when the
    /// kernel C function is not yet exposed. The coordinator layer uses this
    /// to fall back to the Swift-only path without crashing.
    public func run(request: PrewarmClientRequest) -> PrewarmApplyReport {
        let bridgeRequest = PrewarmRequest(
            frames: request.frames.map {
                PrewarmFrameInput(frameID: $0.frameID, orderIndex: $0.orderIndex)
            },
            canvasWidth: request.canvasWidth,
            canvasHeight: request.canvasHeight,
            priorityTier: bridgePriorityTier(from: request.priorityTier)
        )

        switch bridge.run(request: bridgeRequest) {
        case .success(let result):
            return PrewarmApplyReport(
                computedFrameCount: result.computedFrameCount,
                kernelExecuted: result.kernelExecuted
            )
        case .failure:
            return PrewarmApplyReport(computedFrameCount: 0, kernelExecuted: false)
        }
    }

    /// Builds the user-visible feedback string for a prewarm report.
    public func feedbackMessage(for report: PrewarmApplyReport) -> String {
        guard report.kernelExecuted else {
            return "Prewarm: kernel not available"
        }
        return "\(report.computedFrameCount) frames prewarmed"
    }

    // MARK: - Private helpers

    private func bridgePriorityTier(from tier: PrewarmClientPriority) -> PrewarmPriority {
        switch tier {
        case .high:   return .high
        case .medium: return .medium
        case .low:    return .low
        }
    }
}
