// PreviewRenderBridge.swift
// Layer: ColorAnimaKernelBridge — Bridge entrypoints only. No app-side logic.
//
// Kernel C surface investigation result:
//   (.local-core headers contain only ca_pipeline_version()).
//   Preview render bridge is therefore a documented .unavailable stub returning
//   (or equivalent) C function.
//
//   kernel xcframework header, then wire this Bridge to it. The DTO shapes below
//   are forward-compatible: once the C function is available the #if canImport
//   block is the only change needed.
//
//   1. Public DTOs only — names scoped to Bridge target (Preview* prefix).
//   2. Opaque handles — kernel-resident state as OpaquePointer-backed handle.
//   3. Result returns — every call returns Result<DTO, KernelBridgeError>.
//   4. No-binary fallback — compiles and runs when #if !canImport(ColorAnimaKernel).
//   5. Symbol-scan clean — no banned terms from the red-team deny-list.
//   6. 3-layer split — Bridge owns FFI; AppEngine owns public client; workspace owns orchestration.

#if canImport(ColorAnimaKernel)
import ColorAnimaKernel
#endif

import Foundation

// MARK: - Bridge DTOs

/// An opaque reference to a preview render session held inside the kernel.
/// Crosses the FFI boundary without exposing any kernel-internal type.
///
/// @unchecked Sendable: OpaquePointer does not itself conform to Sendable in
/// Swift 6. The kernel guarantees that this handle is immutable after creation
/// and that its lifetime is managed by the Bridge layer exclusively.
public struct PreviewRenderHandle: Equatable, @unchecked Sendable {
    /// Opaque pointer to the kernel-resident session. nil when kernel is unavailable.
    public let pointer: OpaquePointer?

    public init(pointer: OpaquePointer?) {
        self.pointer = pointer
    }
}

/// Canvas geometry passed to the preview render bridge.
public struct PreviewRenderCanvasDescriptor: Equatable, Sendable {
    /// Canvas width in pixels.
    public let width: Int
    /// Canvas height in pixels.
    public let height: Int

    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }
}

/// Per-frame input descriptor for a preview rebuild request.
public struct PreviewRenderFrameInput: Equatable, Sendable {
    /// Stable identifier for this frame.
    public let frameID: UUID
    /// Zero-based position of this frame in the cut sequence.
    public let orderIndex: Int
    /// Whether the overlay image has been computed for this frame.
    public let hasComputedOverlay: Bool

    public init(frameID: UUID, orderIndex: Int, hasComputedOverlay: Bool) {
        self.frameID = frameID
        self.orderIndex = orderIndex
        self.hasComputedOverlay = hasComputedOverlay
    }
}

/// Parameters for a preview rebuild request.
public struct PreviewRenderRequest: Equatable, Sendable {
    /// Canvas geometry.
    public let canvas: PreviewRenderCanvasDescriptor
    /// Frame descriptors for the cut being rendered.
    public let frames: [PreviewRenderFrameInput]
    /// Identifier of the currently selected frame.
    public let selectedFrameID: UUID?

    public init(
        canvas: PreviewRenderCanvasDescriptor,
        frames: [PreviewRenderFrameInput],
        selectedFrameID: UUID?
    ) {
        self.canvas = canvas
        self.frames = frames
        self.selectedFrameID = selectedFrameID
    }
}

/// Result returned from a preview rebuild pass.
public struct PreviewRenderResult: Equatable, Sendable {
    /// Number of frames for which an overlay was computed.
    public let computedFrameCount: Int
    /// Whether the kernel executed the pass (false when C function not yet exposed).
    public let kernelExecuted: Bool

    public init(computedFrameCount: Int, kernelExecuted: Bool) {
        self.computedFrameCount = computedFrameCount
        self.kernelExecuted = kernelExecuted
    }
}

// MARK: - Bridge

/// FFI bridge for the preview render kernel function.
///
/// This is the ONLY type in the app repo that is permitted to import
/// ColorAnimaKernel for preview rendering. All callers must go through this struct.
public struct PreviewRenderBridge: Sendable {

    public init() {}

    /// Runs a preview rebuild pass via the kernel C ABI.
    ///
    /// Returns `.failure(.unavailable)` when the kernel binary is not linked
    /// or when no C-ABI preview rebuild function has been exposed yet.
    ///
    /// - Note: Kernel C surface investigation (2026-05-03): only
    ///   ca_pipeline_version() is currently exposed. This method returns
    ///   kernel xcframework header. Follow-up required in core repo.
    public func run(
        request: PreviewRenderRequest
    ) -> Result<PreviewRenderResult, KernelBridgeError> {
        #if canImport(ColorAnimaKernel)
        // Return .unavailable so the AppEngine layer can fall back gracefully.
        // Replace this stub with the real FFI call once the core repo exposes it.
        return .failure(.unavailable)
        #else
        return .failure(.unavailable)
        #endif
    }

    /// Whether the kernel binary is linked and exposes the preview rebuild C function.
    /// Currently always false (stub; see run()).
    public var isPreviewRenderAvailable: Bool {
        #if canImport(ColorAnimaKernel)
        return false
        #else
        return false
        #endif
    }
}
