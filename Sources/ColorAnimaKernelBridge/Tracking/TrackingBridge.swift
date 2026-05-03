// TrackingBridge.swift
// Layer: ColorAnimaKernelBridge — Bridge entrypoints only. No app-side logic.
//
// Kernel C surface investigation result:
//   Only ca_pipeline_version() is currently exposed by the kernel binary.
//   Tracking bridge is therefore a documented stub returning
//   (or equivalent) C function.
//
//   kernel xcframework header, then wire this Bridge to it. The DTO
//   shapes below are forward-compatible: once the C function is available
//   the #if canImport block is the only change needed.
//
//   1. Public DTOs only — names scoped to Bridge target (Tracking* prefix).
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

/// An opaque reference to a tracking session held inside the kernel.
/// Crosses the FFI boundary without exposing any kernel-internal type.
///
/// @unchecked Sendable: OpaquePointer does not itself conform to Sendable in
/// Swift 6. The kernel guarantees that this handle is immutable after creation
/// and that its lifetime is managed by the Bridge layer exclusively.
public struct TrackingHandle: Equatable, @unchecked Sendable {
    /// Opaque pointer to the kernel-resident session. nil when kernel is unavailable.
    public let pointer: OpaquePointer?

    public init(pointer: OpaquePointer?) {
        self.pointer = pointer
    }
}

/// Input frame descriptor for a tracking run.
public struct TrackingFrameInput: Equatable, Sendable {
    /// Stable identifier for this frame.
    public let frameID: UUID
    /// Zero-based position of this frame in the cut sequence.
    public let orderIndex: Int
    /// Whether this frame is a reference (anchor) frame driving propagation.
    public let isKeyFrame: Bool

    public init(frameID: UUID, orderIndex: Int, isKeyFrame: Bool) {
        self.frameID = frameID
        self.orderIndex = orderIndex
        self.isKeyFrame = isKeyFrame
    }
}

/// Per-frame result returned from the kernel after a tracking run.
public struct TrackingFrameResult: Equatable, Sendable {
    /// Stable identifier matching the corresponding input frame.
    public let frameID: UUID
    /// Number of region correspondences resolved for this frame.
    public let resolvedCorrespondenceCount: Int

    public init(frameID: UUID, resolvedCorrespondenceCount: Int) {
        self.frameID = frameID
        self.resolvedCorrespondenceCount = resolvedCorrespondenceCount
    }
}

/// Aggregate result returned from a tracking run.
public struct TrackingResult: Equatable, Sendable {
    /// Per-frame results, keyed by frame identifier.
    public let frameResults: [UUID: TrackingFrameResult]
    /// Total number of region correspondences resolved across all frames.
    public let totalResolvedCount: Int
    /// Whether the run completed without cancellation.
    public let completed: Bool

    public init(
        frameResults: [UUID: TrackingFrameResult],
        totalResolvedCount: Int,
        completed: Bool
    ) {
        self.frameResults = frameResults
        self.totalResolvedCount = totalResolvedCount
        self.completed = completed
    }
}

/// Parameters controlling a tracking run.
public struct TrackingRequest: Equatable, Sendable {
    /// Ordered input frames (the full cut sequence).
    public let frames: [TrackingFrameInput]
    /// Frame identifiers designated as reference (anchor) frames.
    public let keyFrameIDs: Set<UUID>
    /// Canvas width in pixels.
    public let canvasWidth: Int
    /// Canvas height in pixels.
    public let canvasHeight: Int

    public init(
        frames: [TrackingFrameInput],
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

// MARK: - Bridge

/// FFI bridge for the tracking kernel function.
///
/// This is the ONLY type in the app repo that is permitted to import
/// ColorAnimaKernel for tracking operations. All callers must go through
/// this struct.
public struct TrackingBridge: Sendable {

    public init() {}

    /// Runs a tracking pass via the kernel C ABI.
    ///
    /// Returns `.failure(.unavailable)` when the kernel binary is not linked
    /// or when no C-ABI tracking function has been exposed yet.
    ///
    /// - Note: Kernel C surface investigation (2026-05-03): only
    ///   ca_pipeline_version() is currently exposed. This method returns
    ///   kernel xcframework header. Follow-up required in core repo.
    public func run(
        request: TrackingRequest
    ) -> Result<TrackingResult, KernelBridgeError> {
        #if canImport(ColorAnimaKernel)
        // Return .unavailable so the AppEngine layer can fall back gracefully.
        // Replace this stub with the real FFI call once the core repo exposes it.
        return .failure(.unavailable)
        #else
        return .failure(.unavailable)
        #endif
    }

    /// Returns whether the kernel binary is linked and exposes the tracking
    /// C function. Currently always false (stub; see run()).
    public var isTrackingAvailable: Bool {
        #if canImport(ColorAnimaKernel)
        return false
        #else
        return false
        #endif
    }
}
