// RegionRewriteBridge.swift
// Layer: ColorAnimaKernelBridge — Bridge entrypoints only. No app-side logic.
//
// Kernel C surface:
//   ca_engine_run_a is the public activation entry used for bounded region
//   rewrite requests. The current public DTO carries frame identity/window
//   metadata; it does not yet carry region payloads, so the adapter sends empty
//   region sets and reports the neutral result counts returned by the kernel.
//
//   1. Public DTOs only — names scoped to Bridge target (RegionRewrite* prefix).
//   2. Opaque handles — kernel-resident state as OpaquePointer-backed KernelHandle.
//   3. Result returns — every call returns Result<DTO, KernelBridgeError>.
//   4. No-binary fallback — compiles and runs when #if !canImport(ColorAnimaKernel).
//   5. Symbol-scan clean — no banned terms from the red-team deny-list.
//   6. 3-layer split — Bridge owns FFI; AppEngine owns public client; workspace owns orchestration.

#if canImport(ColorAnimaKernel)
import ColorAnimaKernel
#endif

import Foundation

// MARK: - Bridge DTOs

/// An opaque reference to a region rewrite session held inside the kernel.
/// Crosses the FFI boundary without exposing any kernel-internal type.
///
/// @unchecked Sendable: OpaquePointer does not itself conform to Sendable in
/// Swift 6. The kernel guarantees that this handle is immutable after creation
/// and that its lifetime is managed by the Bridge layer exclusively.
public struct RegionRewriteHandle: Equatable, @unchecked Sendable {
    /// Opaque pointer to the kernel-resident session. nil when kernel is unavailable.
    public let pointer: OpaquePointer?

    public init(pointer: OpaquePointer?) {
        self.pointer = pointer
    }
}

/// Input frame descriptor for a region rewrite run.
public struct RegionRewriteFrameInput: Equatable, Sendable {
    /// Stable identifier for this frame.
    public let frameID: UUID
    /// Zero-based position of this frame in the cut sequence.
    public let orderIndex: Int
    /// Whether this frame carries a reference (anchor) color assignment.
    public let isKeyFrame: Bool

    public init(frameID: UUID, orderIndex: Int, isKeyFrame: Bool) {
        self.frameID = frameID
        self.orderIndex = orderIndex
        self.isKeyFrame = isKeyFrame
    }
}

/// Per-frame result returned from the kernel after a region rewrite run.
public struct RegionRewriteFrameResult: Equatable, Sendable {
    /// Stable identifier matching the corresponding input frame.
    public let frameID: UUID
    /// Number of region correspondences updated in this frame.
    public let updatedRegionCount: Int

    public init(frameID: UUID, updatedRegionCount: Int) {
        self.frameID = frameID
        self.updatedRegionCount = updatedRegionCount
    }
}

/// Aggregate result returned from a region rewrite run.
public struct RegionRewriteResult: Equatable, Sendable {
    /// Per-frame results, keyed by frame identifier.
    public let frameResults: [UUID: RegionRewriteFrameResult]
    /// Total number of region correspondences rewritten across the window.
    public let totalRewrittenCount: Int
    /// Total number of manual overrides preserved inside the window.
    public let totalPreservedOverrideCount: Int

    public init(
        frameResults: [UUID: RegionRewriteFrameResult],
        totalRewrittenCount: Int,
        totalPreservedOverrideCount: Int
    ) {
        self.frameResults = frameResults
        self.totalRewrittenCount = totalRewrittenCount
        self.totalPreservedOverrideCount = totalPreservedOverrideCount
    }
}

/// Parameters controlling a region rewrite run.
public struct RegionRewriteRequest: Equatable, Sendable {
    /// Ordered input frames (the full cut sequence; the kernel uses applyRange to limit work).
    public let frames: [RegionRewriteFrameInput]
    /// The contiguous frame order-index window over which apply window is scoped.
    public let applyRange: ClosedRange<Int>
    /// Frame identifiers whose region assignments must not be rewritten.
    public let pinnedFrameIDs: Set<UUID>
    /// Canvas width in pixels.
    public let canvasWidth: Int
    /// Canvas height in pixels.
    public let canvasHeight: Int

    public init(
        frames: [RegionRewriteFrameInput],
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

// MARK: - Bridge

/// FFI bridge for the region rewrite kernel function.
///
/// This is the ONLY type in the app repo that is permitted to import
/// ColorAnimaKernel. All callers must go through this struct.
public struct RegionRewriteBridge: Sendable {

    public init() {}

    /// Runs a region rewrite pass via the kernel C ABI.
    ///
    /// Returns `.failure(.unavailable)` when the kernel binary is not linked
    /// or the neutral activation request cannot be executed.
    public func run(
        request: RegionRewriteRequest
    ) -> Result<RegionRewriteResult, KernelBridgeError> {
        #if canImport(ColorAnimaKernel)
        guard let result = KernelActivationWire.runBoundedPropagation(
            frames: request.frames,
            applyRange: request.applyRange,
            pinnedFrameIDs: request.pinnedFrameIDs,
            canvasWidth: request.canvasWidth,
            canvasHeight: request.canvasHeight
        ) else {
            return .failure(.unavailable)
        }
        let frameResults = Dictionary(
            uniqueKeysWithValues: result.frameResults.map {
                (
                    $0.frameID,
                    RegionRewriteFrameResult(
                        frameID: $0.frameID,
                        updatedRegionCount: $0.correspondenceCount
                    )
                )
            }
        )
        return .success(
            RegionRewriteResult(
                frameResults: frameResults,
                totalRewrittenCount: result.totalCorrespondenceCount,
                totalPreservedOverrideCount: 0
            )
        )
        #else
        return .failure(.unavailable)
        #endif
    }

    /// Returns whether the kernel binary is linked and exposes the bounded C entry.
    public var isRegionRewriteAvailable: Bool {
        #if canImport(ColorAnimaKernel)
        return true
        #else
        return false
        #endif
    }
}
