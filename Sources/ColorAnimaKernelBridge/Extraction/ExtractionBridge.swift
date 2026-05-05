// ExtractionBridge.swift
// Layer: ColorAnimaKernelBridge — Bridge entrypoints only. No app-side logic.
//
// Kernel C surface:
//   ca_engine_run_c is the public activation entry used for extraction
//   requests. The current public DTO carries frame identity and canvas size; it
//   does not yet carry raster data, so the adapter executes a neutral opaque
//   alpha-plane request per frame and reports the kernel's region counts.
//
//   1. Public DTOs only — names scoped to Bridge target (Extraction* prefix).
//   2. Result returns — every call returns Result<DTO, KernelBridgeError>.
//   3. No-binary fallback — compiles and runs when #if !canImport(ColorAnimaKernel).
//   4. Symbol-scan clean — no banned terms from the red-team deny-list.
//   5. 3-layer split — Bridge owns FFI; AppEngine owns public client; workspace owns orchestration.

#if canImport(ColorAnimaKernel)
import ColorAnimaKernel
#endif

import Foundation

// MARK: - Bridge DTOs

/// Per-frame input descriptor for an extraction request.
public struct ExtractionFrameInput: Equatable, Sendable {
    /// Stable identifier for this frame.
    public let frameID: UUID
    /// Zero-based position of this frame in the cut sequence.
    public let orderIndex: Int

    public init(frameID: UUID, orderIndex: Int) {
        self.frameID = frameID
        self.orderIndex = orderIndex
    }
}

/// Per-frame result returned from the kernel after an extraction pass.
public struct ExtractionFrameResult: Equatable, Sendable {
    /// Stable identifier matching the corresponding input frame.
    public let frameID: UUID
    /// Number of regions detected in this frame.
    public let regionCount: Int
    /// Number of fill boundary candidates identified.
    public let additionalRegionCount: Int

    public init(frameID: UUID, regionCount: Int, additionalRegionCount: Int) {
        self.frameID = frameID
        self.regionCount = regionCount
        self.additionalRegionCount = additionalRegionCount
    }
}

/// Aggregate result returned from an extraction pass.
public struct ExtractionResult: Equatable, Sendable {
    /// Per-frame results keyed by frame identifier.
    public let frameResults: [UUID: ExtractionFrameResult]
    /// Total number of regions detected across all frames.
    public let totalRegionCount: Int
    /// Total number of fill boundary candidates across all frames.
    public let totalAdditionalRegionCount: Int

    public init(
        frameResults: [UUID: ExtractionFrameResult],
        totalRegionCount: Int,
        totalAdditionalRegionCount: Int
    ) {
        self.frameResults = frameResults
        self.totalRegionCount = totalRegionCount
        self.totalAdditionalRegionCount = totalAdditionalRegionCount
    }
}

/// Parameters controlling an extraction pass.
public struct ExtractionRequest: Equatable, Sendable {
    /// Ordered input frames to extract.
    public let frames: [ExtractionFrameInput]
    /// Canvas width in pixels.
    public let canvasWidth: Int
    /// Canvas height in pixels.
    public let canvasHeight: Int

    public init(frames: [ExtractionFrameInput], canvasWidth: Int, canvasHeight: Int) {
        self.frames = frames
        self.canvasWidth = canvasWidth
        self.canvasHeight = canvasHeight
    }
}

// MARK: - Bridge

/// FFI bridge for the extraction kernel function.
///
/// - Only this target imports ColorAnimaKernel.
/// - All callers go through this struct.
/// - Returns .failure(.unavailable) when the kernel function cannot execute.
public struct ExtractionBridge: Sendable {

    public init() {}

    /// Runs an extraction pass via the kernel C ABI.
    ///
    /// Returns `.failure(.unavailable)` when the kernel binary is not linked
    /// or the neutral activation request cannot be executed.
    public func run(
        request: ExtractionRequest
    ) -> Result<ExtractionResult, KernelBridgeError> {
        #if canImport(ColorAnimaKernel)
        guard request.frames.isEmpty == false else {
            return .failure(.unavailable)
        }

        var frameResults: [UUID: ExtractionFrameResult] = [:]
        var totalRegionCount = 0
        for frame in request.frames {
            guard let result = KernelActivationWire.runExtraction(
                canvasWidth: request.canvasWidth,
                canvasHeight: request.canvasHeight
            ) else {
                return .failure(.unavailable)
            }
            let frameResult = ExtractionFrameResult(
                frameID: frame.frameID,
                regionCount: result.regionCount,
                additionalRegionCount: 0
            )
            frameResults[frame.frameID] = frameResult
            totalRegionCount += result.regionCount
        }
        return .success(
            ExtractionResult(
                frameResults: frameResults,
                totalRegionCount: totalRegionCount,
                totalAdditionalRegionCount: 0
            )
        )
        #else
        return .failure(.unavailable)
        #endif
    }

    /// Returns whether the kernel binary is linked and exposes the extraction C entry.
    public var isExtractionAvailable: Bool {
        #if canImport(ColorAnimaKernel)
        return true
        #else
        return false
        #endif
    }
}
