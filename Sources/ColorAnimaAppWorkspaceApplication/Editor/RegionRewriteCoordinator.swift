// RegionRewriteCoordinator.swift
// Layer: ColorAnimaAppWorkspaceApplication — orchestration on top of the AppEngine client.
//
// This coordinator replaces the deleted source-only region rewrite coordinator
// using public DTOs throughout. It does NOT import ColorAnimaKernel, ColorAnimaKernelBridge,
// or any source-only kernel module. All kernel access flows via the AppEngine client.
//
// The coordinator is intentionally UI-free and MainActor-free: it operates on pure
// value types and delegates all model mutation to the call site via its return values.

import Foundation

// MARK: - Public DTOs

/// Summary of a region rewrite apply passed back to the call site.
public struct RegionRewriteReport: Hashable, Equatable, Sendable {
    /// Number of region correspondences rewritten across the window.
    public var rewrittenRegionCount: Int
    /// Number of manual overrides preserved inside the window.
    public var preservedOverrideCount: Int
    /// Frame order-index values inside the window, sorted ascending.
    public var windowFrameIndices: [Int]
    /// Frame identifiers that were inside the window (reference frames included for completeness).
    public var windowFrameIDs: [UUID]
    /// Whether the kernel executed the run (false when the kernel C function is not yet exposed).
    public var kernelExecuted: Bool

    public init(
        rewrittenRegionCount: Int = 0,
        preservedOverrideCount: Int = 0,
        windowFrameIndices: [Int] = [],
        windowFrameIDs: [UUID] = [],
        kernelExecuted: Bool = false
    ) {
        self.rewrittenRegionCount = rewrittenRegionCount
        self.preservedOverrideCount = preservedOverrideCount
        self.windowFrameIndices = windowFrameIndices
        self.windowFrameIDs = windowFrameIDs
        self.kernelExecuted = kernelExecuted
    }
}

/// A single frame descriptor passed into the coordinator from the call site.
public struct RegionRewriteFrameDescriptor: Equatable, Sendable {
    public let frameID: UUID
    public let orderIndex: Int
    public let isKeyFrame: Bool

    public init(frameID: UUID, orderIndex: Int, isKeyFrame: Bool) {
        self.frameID = frameID
        self.orderIndex = orderIndex
        self.isKeyFrame = isKeyFrame
    }
}

// MARK: - Coordinator

/// Orchestrates scoped frame-range update over an app-side AppEngine client.
///
/// All logic is expressed in terms of public DTOs. The coordinator derives
/// propagation windows, builds client requests, and returns reports that the
/// call site applies to its own model. It never holds or mutates workspace state.
public enum RegionRewriteCoordinator {

    /// Maximum frame count allowed for the synchronous reference-edit
    /// propagation path. Windows larger than this threshold must use an async
    /// caller; returning false from the authoritative-edit helper lets facade
    /// callers fall back to the ordinary assignment path.
    public static let synchronousReferenceEditFrameThreshold = 8

    // MARK: - Window derivation

    /// Derives the partial re-propagation window for a newly added reference frame.
    ///
    /// Given sorted reference-frame order indices (including the new reference at
    /// newReferenceIndex), the window spans from the previous reference (or cut
    /// start) to the next reference (or cut end), inclusive.
    ///
    /// The endpoints remain authoritative reference inputs — they are kept inside
    /// the returned range so the engine can use them, but the apply pass skips
    /// reference frames (they are never rewritten).
    public static func deriveWindow(
        referenceFrameIndices: [Int],
        newReferenceIndex: Int,
        cutStartIndex: Int,
        cutEndIndex: Int
    ) -> ClosedRange<Int> {
        let sorted = referenceFrameIndices.sorted()
        let prev = sorted.last { $0 < newReferenceIndex } ?? cutStartIndex
        let next = sorted.first { $0 > newReferenceIndex } ?? cutEndIndex
        let lower = max(prev, cutStartIndex)
        let upper = min(next, cutEndIndex)
        let clampedLower = min(lower, newReferenceIndex)
        let clampedUpper = max(upper, newReferenceIndex)
        return clampedLower ... clampedUpper
    }

    // MARK: - Run

    /// Runs a region rewrite pass via the supplied AppEngine client.
    ///
    /// Returns a RegionRewriteReport with kernelExecuted = false when the
    /// kernel C function is not yet exposed. The call site decides how to handle
    /// the unavailable case (e.g. log, surface a message, fall back to no-op).
    ///
    /// - Parameters:
    ///   - frames: All frame descriptors in the cut, ordered by orderIndex.
    ///   - window: The contiguous order-index range to propagate over.
    ///   - pinnedFrameIDs: Frame identifiers whose assignments must not be rewritten.
    ///   - canvasWidth: Canvas width in pixels.
    ///   - canvasHeight: Canvas height in pixels.
    ///   - client: AppEngine client to delegate the Bridge call to.
    public static func run(
        frames: [RegionRewriteFrameDescriptor],
        window: ClosedRange<Int>,
        pinnedFrameIDs: Set<UUID>,
        canvasWidth: Int,
        canvasHeight: Int,
        client: RegionRewriteClientProtocol
    ) -> RegionRewriteReport {
        let windowFrames = frames.filter { window.contains($0.orderIndex) }
        let windowFrameIndices = windowFrames.map(\.orderIndex).sorted()
        let windowFrameIDs = windowFrames.map(\.frameID)

        let clientFrames = frames.map {
            RegionRewriteCoordinatorFrameInput(
                frameID: $0.frameID,
                orderIndex: $0.orderIndex,
                isKeyFrame: $0.isKeyFrame
            )
        }

        let applyReport = client.run(
            frames: clientFrames,
            applyRange: window,
            pinnedFrameIDs: pinnedFrameIDs,
            canvasWidth: canvasWidth,
            canvasHeight: canvasHeight
        )

        return RegionRewriteReport(
            rewrittenRegionCount: applyReport.rewrittenRegionCount,
            preservedOverrideCount: applyReport.preservedOverrideCount,
            windowFrameIndices: windowFrameIndices,
            windowFrameIDs: windowFrameIDs,
            kernelExecuted: applyReport.kernelExecuted
        )
    }

    /// Builds the user-visible feedback string for a region rewrite report.
    public static func feedbackMessage(for report: RegionRewriteReport) -> String {
        let frameCount = report.windowFrameIndices.count
        guard report.kernelExecuted else {
            return "\(frameCount) frames in window, region rewrite kernel not yet available"
        }
        return "\(frameCount) frames affected, \(report.rewrittenRegionCount) regions updated, \(report.preservedOverrideCount) overrides preserved"
    }

    /// Validates whether a window is within the synchronous frame threshold.
    ///
    /// Returns false when the window exceeds synchronousReferenceEditFrameThreshold,
    /// signalling that the caller should use an async path instead.
    public static func isWithinSynchronousThreshold(window: ClosedRange<Int>) -> Bool {
        let count = window.upperBound - window.lowerBound + 1
        return count <= synchronousReferenceEditFrameThreshold
    }
}

// MARK: - Protocol for testability

/// Internal frame input type used to hand data to the client protocol.
/// Not a public exported type — callers use RegionRewriteFrameDescriptor.
public struct RegionRewriteCoordinatorFrameInput: Equatable, Sendable {
    public let frameID: UUID
    public let orderIndex: Int
    public let isKeyFrame: Bool

    public init(frameID: UUID, orderIndex: Int, isKeyFrame: Bool) {
        self.frameID = frameID
        self.orderIndex = orderIndex
        self.isKeyFrame = isKeyFrame
    }
}

/// Return type from the client protocol — mirrors RegionRewriteApplyReport
/// without requiring a direct import of ColorAnimaAppEngine in this target.
public struct RegionRewriteCoordinatorApplyReport: Equatable, Sendable {
    public let rewrittenRegionCount: Int
    public let preservedOverrideCount: Int
    public let kernelExecuted: Bool

    public init(rewrittenRegionCount: Int, preservedOverrideCount: Int, kernelExecuted: Bool) {
        self.rewrittenRegionCount = rewrittenRegionCount
        self.preservedOverrideCount = preservedOverrideCount
        self.kernelExecuted = kernelExecuted
    }
}

/// Protocol that RegionRewriteClient (AppEngine layer) conforms to,
/// allowing the coordinator to be tested with a stub client.
public protocol RegionRewriteClientProtocol: Sendable {
    func run(
        frames: [RegionRewriteCoordinatorFrameInput],
        applyRange: ClosedRange<Int>,
        pinnedFrameIDs: Set<UUID>,
        canvasWidth: Int,
        canvasHeight: Int
    ) -> RegionRewriteCoordinatorApplyReport
}
