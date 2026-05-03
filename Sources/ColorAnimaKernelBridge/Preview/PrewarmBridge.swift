// PrewarmBridge.swift
// Layer: ColorAnimaKernelBridge — Bridge entrypoints only. No app-side logic.
//
// Kernel C surface investigation result:
//   (.local-core headers contain only ca_pipeline_version()).
//   Prewarm bridge is therefore a documented .unavailable stub returning
//   (or equivalent) C function.
//
//   xcframework header, then wire this Bridge to it. The DTO shapes below are
//   forward-compatible: once the C function is available the #if canImport
//   block is the only change needed.
//
//   1. Public DTOs only — names scoped to Bridge target (Prewarm* prefix).
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

/// An opaque reference to a prewarm session held inside the kernel.
/// Crosses the FFI boundary without exposing any kernel-internal type.
///
/// @unchecked Sendable: OpaquePointer does not itself conform to Sendable in
/// Swift 6. The kernel guarantees that this handle is immutable after creation
/// and that its lifetime is managed by the Bridge layer exclusively.
public struct PrewarmHandle: Equatable, @unchecked Sendable {
    /// Opaque pointer to the kernel-resident session. nil when kernel is unavailable.
    public let pointer: OpaquePointer?

    public init(pointer: OpaquePointer?) {
        self.pointer = pointer
    }
}

/// Priority tier for a prewarm request.
public enum PrewarmPriority: Equatable, Sendable {
    /// Highest priority.
    case high
    /// Medium priority.
    case medium
    /// Lowest priority.
    case low
}

/// Per-frame input descriptor for a prewarm request.
public struct PrewarmFrameInput: Equatable, Sendable {
    /// Stable identifier for this frame.
    public let frameID: UUID
    /// Zero-based position of this frame in the cut sequence.
    public let orderIndex: Int

    public init(frameID: UUID, orderIndex: Int) {
        self.frameID = frameID
        self.orderIndex = orderIndex
    }
}

/// Parameters for a prewarm execution request.
public struct PrewarmRequest: Equatable, Sendable {
    /// Frames to prewarm (inactive frames only; active frame filtered before this layer).
    public let frames: [PrewarmFrameInput]
    /// Canvas width in pixels.
    public let canvasWidth: Int
    /// Canvas height in pixels.
    public let canvasHeight: Int
    /// Priority tier controlling kernel scheduling behavior.
    public let priorityTier: PrewarmPriority

    public init(
        frames: [PrewarmFrameInput],
        canvasWidth: Int,
        canvasHeight: Int,
        priorityTier: PrewarmPriority
    ) {
        self.frames = frames
        self.canvasWidth = canvasWidth
        self.canvasHeight = canvasHeight
        self.priorityTier = priorityTier
    }
}

/// Per-frame outcome from a prewarm pass.
public struct PrewarmFrameResult: Equatable, Sendable {
    /// Stable identifier matching the corresponding input frame.
    public let frameID: UUID
    /// Whether the preview state was computed for this frame.
    public let previewStateComputed: Bool

    public init(frameID: UUID, previewStateComputed: Bool) {
        self.frameID = frameID
        self.previewStateComputed = previewStateComputed
    }
}

/// Aggregate result returned from a prewarm pass.
public struct PrewarmResult: Equatable, Sendable {
    /// Per-frame outcomes.
    public let frameResults: [UUID: PrewarmFrameResult]
    /// Total number of frames for which preview state was computed.
    public let computedFrameCount: Int
    /// Whether the kernel executed the pass (false when C function not yet exposed).
    public let kernelExecuted: Bool

    public init(
        frameResults: [UUID: PrewarmFrameResult],
        computedFrameCount: Int,
        kernelExecuted: Bool
    ) {
        self.frameResults = frameResults
        self.computedFrameCount = computedFrameCount
        self.kernelExecuted = kernelExecuted
    }
}

// MARK: - Bridge

/// FFI bridge for the prewarm kernel function.
///
/// This is the ONLY type in the app repo that is permitted to import
/// ColorAnimaKernel for prewarm execution. All callers must go through this struct.
public struct PrewarmBridge: Sendable {

    public init() {}

    /// Runs a prewarm pass via the kernel C ABI.
    ///
    /// Returns `.failure(.unavailable)` when the kernel binary is not linked
    /// or when no C-ABI prewarm function has been exposed yet.
    ///
    /// - Note: Kernel C surface investigation (2026-05-03): only
    ///   ca_pipeline_version() is currently exposed. This method returns
    ///   kernel xcframework header. Follow-up required in core repo.
    public func run(
        request: PrewarmRequest
    ) -> Result<PrewarmResult, KernelBridgeError> {
        #if canImport(ColorAnimaKernel)
        // Return .unavailable so the AppEngine layer can fall back gracefully.
        // Replace this stub with the real FFI call once the core repo exposes it.
        return .failure(.unavailable)
        #else
        return .failure(.unavailable)
        #endif
    }

    /// Whether the kernel binary is linked and exposes the prewarm C function.
    /// Currently always false (stub; see run()).
    public var isPrewarmAvailable: Bool {
        #if canImport(ColorAnimaKernel)
        return false
        #else
        return false
        #endif
    }
}
