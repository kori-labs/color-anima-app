// PreviewRenderClient.swift
// Layer: ColorAnimaAppEngine — public app-side client wrapping the Bridge call.
// Translates between public app DTOs and Bridge DTOs.
// Does NOT import ColorAnimaKernel directly; all kernel access goes via the Bridge.

import ColorAnimaKernelBridge
import Foundation

// MARK: - AppEngine-side DTOs

/// Summary of a preview render pass for user-visible feedback.
public struct PreviewRenderReport: Equatable, Sendable {
    /// Number of frames for which an overlay was computed.
    public let computedFrameCount: Int
    /// Whether the kernel executed the pass (false when running in stub/unavailable mode).
    public let kernelExecuted: Bool

    public init(computedFrameCount: Int, kernelExecuted: Bool) {
        self.computedFrameCount = computedFrameCount
        self.kernelExecuted = kernelExecuted
    }
}

/// Public frame descriptor used by app-side callers of PreviewRenderClient.
public struct PreviewRenderClientFrameInput: Equatable, Sendable {
    public let frameID: UUID
    public let orderIndex: Int
    public let hasComputedOverlay: Bool

    public init(frameID: UUID, orderIndex: Int, hasComputedOverlay: Bool) {
        self.frameID = frameID
        self.orderIndex = orderIndex
        self.hasComputedOverlay = hasComputedOverlay
    }
}

/// Parameters for a preview render pass passed to the client.
public struct PreviewRenderClientRequest: Equatable, Sendable {
    /// Canvas width in pixels.
    public let canvasWidth: Int
    /// Canvas height in pixels.
    public let canvasHeight: Int
    /// Frame descriptors for the cut being rendered.
    public let frames: [PreviewRenderClientFrameInput]
    /// Identifier of the currently selected frame.
    public let selectedFrameID: UUID?

    public init(
        canvasWidth: Int,
        canvasHeight: Int,
        frames: [PreviewRenderClientFrameInput],
        selectedFrameID: UUID?
    ) {
        self.canvasWidth = canvasWidth
        self.canvasHeight = canvasHeight
        self.frames = frames
        self.selectedFrameID = selectedFrameID
    }
}

// MARK: - Client

/// App-side client for the preview render Bridge.
///
/// Wraps PreviewRenderBridge and translates between public app DTOs and Bridge
/// DTOs. Callers never interact with Bridge types directly.
///
/// When the kernel binary is not linked (or the C-ABI preview rebuild function
/// is not yet exposed), run() returns a zero-count report with
/// kernelExecuted = false — allowing callers to fall back gracefully.
public struct PreviewRenderClient: Sendable {
    private let bridge: PreviewRenderBridge

    public init(bridge: PreviewRenderBridge = PreviewRenderBridge()) {
        self.bridge = bridge
    }

    /// Whether the underlying kernel function is available.
    /// Currently always false (stub; see PreviewRenderBridge.swift for follow-up notes).
    public var isAvailable: Bool {
        bridge.isPreviewRenderAvailable
    }

    /// Runs a preview rebuild pass and returns a render report.
    ///
    /// Returns a zero-count report with kernelExecuted = false when the
    /// kernel C function is not yet exposed. The coordinator layer uses this
    /// to fall back to the Swift-only path without crashing.
    public func run(request: PreviewRenderClientRequest) -> PreviewRenderReport {
        let bridgeRequest = PreviewRenderRequest(
            canvas: PreviewRenderCanvasDescriptor(
                width: request.canvasWidth,
                height: request.canvasHeight
            ),
            frames: request.frames.map {
                PreviewRenderFrameInput(
                    frameID: $0.frameID,
                    orderIndex: $0.orderIndex,
                    hasComputedOverlay: $0.hasComputedOverlay
                )
            },
            selectedFrameID: request.selectedFrameID
        )

        switch bridge.run(request: bridgeRequest) {
        case .success(let result):
            return PreviewRenderReport(
                computedFrameCount: result.computedFrameCount,
                kernelExecuted: result.kernelExecuted
            )
        case .failure:
            return PreviewRenderReport(computedFrameCount: 0, kernelExecuted: false)
        }
    }

    /// Builds the user-visible feedback string for a render report.
    public func feedbackMessage(for report: PreviewRenderReport) -> String {
        guard report.kernelExecuted else {
            return "Preview render: kernel not available"
        }
        return "\(report.computedFrameCount) frame overlays computed"
    }
}
