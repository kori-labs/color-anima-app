// TrackingClient.swift
// Layer: ColorAnimaAppEngine — public app-side client wrapping the Bridge call.
// Translates between public app DTOs and Bridge DTOs.
// Does NOT import ColorAnimaKernel directly; all kernel access goes via the Bridge.

import ColorAnimaKernelBridge
import Foundation

// MARK: - AppEngine-side DTOs

/// Summary of a tracking run for user-visible feedback.
public struct TrackingApplyReport: Equatable, Sendable {
    /// Total number of region correspondences resolved across all frames.
    public let resolvedCorrespondenceCount: Int
    /// Number of frames processed in this run.
    public let processedFrameCount: Int
    /// Whether the kernel executed the run (false when running in stub/unavailable mode).
    public let kernelExecuted: Bool

    public init(
        resolvedCorrespondenceCount: Int,
        processedFrameCount: Int,
        kernelExecuted: Bool
    ) {
        self.resolvedCorrespondenceCount = resolvedCorrespondenceCount
        self.processedFrameCount = processedFrameCount
        self.kernelExecuted = kernelExecuted
    }
}

/// Public frame descriptor used by app-side callers of TrackingClient.
public struct TrackingClientFrameInput: Equatable, Sendable {
    public let frameID: UUID
    public let orderIndex: Int
    public let isKeyFrame: Bool

    public init(frameID: UUID, orderIndex: Int, isKeyFrame: Bool) {
        self.frameID = frameID
        self.orderIndex = orderIndex
        self.isKeyFrame = isKeyFrame
    }
}

/// Parameters for a tracking run passed to the client.
public struct TrackingClientRequest: Equatable, Sendable {
    /// Ordered input frames (the full cut sequence).
    public let frames: [TrackingClientFrameInput]
    /// Frame identifiers designated as reference (anchor) frames.
    public let keyFrameIDs: Set<UUID>
    /// Canvas width in pixels.
    public let canvasWidth: Int
    /// Canvas height in pixels.
    public let canvasHeight: Int

    public init(
        frames: [TrackingClientFrameInput],
        keyFrameIDs: Set<UUID>,
        canvasWidth: Int,
        canvasHeight: Int
    ) {
        self.frames = frames
        self.keyFrameIDs = keyFrameIDs
        self.canvasWidth = canvasWidth
        self.canvasHeight = canvasHeight
    }
}

// MARK: - Client

/// App-side client for the tracking Bridge.
///
/// Wraps TrackingBridge and translates between public app DTOs and Bridge DTOs.
/// Callers never interact with Bridge types directly.
///
/// When the kernel binary is not linked (or the C-ABI tracking function is not
/// yet exposed), run() returns a zero-count report with kernelExecuted = false —
/// allowing callers to fall back gracefully.
public struct TrackingClient: Sendable {
    private let bridge: TrackingBridge

    public init(bridge: TrackingBridge = TrackingBridge()) {
        self.bridge = bridge
    }

    /// Whether the underlying kernel function is available.
    /// Currently always false (stub; see TrackingBridge.swift for follow-up notes).
    public var isAvailable: Bool {
        bridge.isTrackingAvailable
    }

    /// Runs a tracking pass and returns an apply report.
    ///
    /// Returns a zero-count report with kernelExecuted = false when the
    /// kernel C function is not yet exposed. The coordinator layer uses this
    /// to fall back to the Swift-only path without crashing.
    public func run(
        request: TrackingClientRequest
    ) -> TrackingApplyReport {
        let bridgeRequest = TrackingRequest(
            frames: request.frames.map {
                TrackingFrameInput(
                    frameID: $0.frameID,
                    orderIndex: $0.orderIndex,
                    isKeyFrame: $0.isKeyFrame
                )
            },
            keyFrameIDs: request.keyFrameIDs,
            canvasWidth: request.canvasWidth,
            canvasHeight: request.canvasHeight
        )

        switch bridge.run(request: bridgeRequest) {
        case .success(let result):
            return TrackingApplyReport(
                resolvedCorrespondenceCount: result.totalResolvedCount,
                processedFrameCount: result.frameResults.count,
                kernelExecuted: true
            )
        case .failure:
            return TrackingApplyReport(
                resolvedCorrespondenceCount: 0,
                processedFrameCount: 0,
                kernelExecuted: false
            )
        }
    }

    /// Builds the user-visible feedback string for an apply report.
    public func feedbackMessage(for report: TrackingApplyReport) -> String {
        guard report.kernelExecuted else {
            return "Tracking: kernel not available"
        }
        return "\(report.processedFrameCount) frames processed, \(report.resolvedCorrespondenceCount) correspondences resolved"
    }
}
