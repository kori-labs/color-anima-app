// RegionRewriteClient.swift
// Layer: ColorAnimaAppEngine — public app-side client wrapping the Bridge call.
// Translates between public app DTOs and Bridge DTOs.
// Does NOT import ColorAnimaKernel directly; all kernel access goes via the Bridge.

import ColorAnimaKernelBridge
import Foundation

// MARK: - AppEngine-side DTOs

/// Summary of a region rewrite run for user-visible feedback.
public struct RegionRewriteApplyReport: Equatable, Sendable {
    /// Number of region correspondences rewritten across the window.
    public let rewrittenRegionCount: Int
    /// Number of manual overrides preserved inside the window.
    public let preservedOverrideCount: Int
    /// Whether the kernel executed the run (false when running in stub/unavailable mode).
    public let kernelExecuted: Bool

    public init(
        rewrittenRegionCount: Int,
        preservedOverrideCount: Int,
        kernelExecuted: Bool
    ) {
        self.rewrittenRegionCount = rewrittenRegionCount
        self.preservedOverrideCount = preservedOverrideCount
        self.kernelExecuted = kernelExecuted
    }
}

/// Public frame descriptor used by app-side callers of RegionRewriteClient.
public struct RegionRewriteClientFrameInput: Equatable, Sendable {
    public let frameID: UUID
    public let orderIndex: Int
    public let isKeyFrame: Bool

    public init(frameID: UUID, orderIndex: Int, isKeyFrame: Bool) {
        self.frameID = frameID
        self.orderIndex = orderIndex
        self.isKeyFrame = isKeyFrame
    }
}

/// Parameters for a region rewrite run passed to the client.
public struct RegionRewriteClientRequest: Equatable, Sendable {
    /// Ordered input frames (the full cut sequence).
    public let frames: [RegionRewriteClientFrameInput]
    /// The contiguous frame order-index window to propagate over.
    public let applyRange: ClosedRange<Int>
    /// Frame identifiers whose region assignments must not be rewritten.
    public let pinnedFrameIDs: Set<UUID>
    /// Canvas width in pixels.
    public let canvasWidth: Int
    /// Canvas height in pixels.
    public let canvasHeight: Int

    public init(
        frames: [RegionRewriteClientFrameInput],
        applyRange: ClosedRange<Int>,
        pinnedFrameIDs: Set<UUID>,
        canvasWidth: Int,
        canvasHeight: Int
    ) {
        self.frames = frames
        self.applyRange = applyRange
        self.pinnedFrameIDs = pinnedFrameIDs
        self.canvasWidth = canvasWidth
        self.canvasHeight = canvasHeight
    }
}

// MARK: - Client

/// App-side client for the region rewrite Bridge.
///
/// Wraps RegionRewriteBridge and translates between public app DTOs
/// and Bridge DTOs. Callers never interact with Bridge types directly.
///
/// When the kernel binary is not linked (or the C-ABI region rewrite
/// function is not yet exposed), run() returns a zero-count report with
/// kernelExecuted = false — allowing callers to fall back gracefully.
public struct RegionRewriteClient: Sendable {
    private let bridge: RegionRewriteBridge

    public init(bridge: RegionRewriteBridge = RegionRewriteBridge()) {
        self.bridge = bridge
    }

    /// Whether the underlying kernel function is available.
    /// Currently always false (stub; see RegionRewriteBridge.swift for follow-up notes).
    public var isAvailable: Bool {
        bridge.isRegionRewriteAvailable
    }

    /// Runs a region rewrite pass and returns an apply report.
    ///
    /// Returns a zero-count report with kernelExecuted = false when the
    /// kernel C function is not yet exposed. The coordinator layer uses this
    /// to fall back to the Swift-only path without crashing.
    public func run(
        request: RegionRewriteClientRequest
    ) -> RegionRewriteApplyReport {
        let bridgeRequest = RegionRewriteRequest(
            frames: request.frames.map {
                RegionRewriteFrameInput(
                    frameID: $0.frameID,
                    orderIndex: $0.orderIndex,
                    isKeyFrame: $0.isKeyFrame
                )
            },
            applyRange: request.applyRange,
            pinnedFrameIDs: request.pinnedFrameIDs,
            canvasWidth: request.canvasWidth,
            canvasHeight: request.canvasHeight
        )

        switch bridge.run(request: bridgeRequest) {
        case .success(let result):
            return RegionRewriteApplyReport(
                rewrittenRegionCount: result.totalRewrittenCount,
                preservedOverrideCount: result.totalPreservedOverrideCount,
                kernelExecuted: true
            )
        case .failure:
            return RegionRewriteApplyReport(
                rewrittenRegionCount: 0,
                preservedOverrideCount: 0,
                kernelExecuted: false
            )
        }
    }

    /// Builds the user-visible feedback string for an apply report.
    public func feedbackMessage(for report: RegionRewriteApplyReport) -> String {
        guard report.kernelExecuted else {
            return "Region rewrite: kernel not available"
        }
        return "\(report.rewrittenRegionCount) regions updated, \(report.preservedOverrideCount) overrides preserved"
    }
}
