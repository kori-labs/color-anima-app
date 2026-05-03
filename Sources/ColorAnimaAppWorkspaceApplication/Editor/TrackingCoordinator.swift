// TrackingCoordinator.swift
// Layer: ColorAnimaAppWorkspaceApplication — orchestration on top of the AppEngine client.
//
// This coordinator replaces the deleted source-only tracking coordinator
// using public DTOs throughout. It does NOT import ColorAnimaKernel,
// ColorAnimaKernelBridge, or any source-only kernel module. All kernel
// access flows via the AppEngine client.
//
// The coordinator is intentionally UI-free and MainActor-free: it operates
// on pure value types and delegates all model mutation to the call site via
// its return values.

import Foundation

// MARK: - Public DTOs

/// Summary of a tracking run passed back to the call site.
public struct TrackingRunReport: Hashable, Equatable, Sendable {
    /// Total number of region correspondences resolved across all frames.
    public var resolvedCorrespondenceCount: Int
    /// Number of frames that were processed in this run.
    public var processedFrameCount: Int
    /// Frame identifiers that were included in this run.
    public var processedFrameIDs: [UUID]
    /// Whether the kernel executed the run (false when the kernel C function is not yet exposed).
    public var kernelExecuted: Bool

    public init(
        resolvedCorrespondenceCount: Int = 0,
        processedFrameCount: Int = 0,
        processedFrameIDs: [UUID] = [],
        kernelExecuted: Bool = false
    ) {
        self.resolvedCorrespondenceCount = resolvedCorrespondenceCount
        self.processedFrameCount = processedFrameCount
        self.processedFrameIDs = processedFrameIDs
        self.kernelExecuted = kernelExecuted
    }
}

/// A single frame descriptor passed into the coordinator from the call site.
public struct TrackingFrameDescriptor: Equatable, Sendable {
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

/// Orchestrates tracking runs over an app-side AppEngine client.
///
/// All logic is expressed in terms of public DTOs. The coordinator builds
/// client requests and returns reports that the call site applies to its own
/// model. It never holds or mutates workspace state.
public enum TrackingCoordinator {

    // MARK: - Run

    /// Runs a tracking pass via the supplied AppEngine client.
    ///
    /// Returns a TrackingRunReport with kernelExecuted = false when the
    /// kernel C function is not yet exposed. The call site decides how to
    /// handle the unavailable case (e.g. log, surface a message, fall back
    /// to no-op).
    ///
    /// - Parameters:
    ///   - frames: All frame descriptors in the cut, ordered by orderIndex.
    ///   - keyFrameIDs: Frame identifiers designated as reference frames.
    ///   - canvasWidth: Canvas width in pixels.
    ///   - canvasHeight: Canvas height in pixels.
    ///   - client: AppEngine client to delegate the Bridge call to.
    public static func run(
        frames: [TrackingFrameDescriptor],
        keyFrameIDs: Set<UUID>,
        canvasWidth: Int,
        canvasHeight: Int,
        client: TrackingClientProtocol
    ) -> TrackingRunReport {
        let processedFrameIDs = frames.map(\.frameID)

        let clientFrames = frames.map {
            TrackingCoordinatorFrameInput(
                frameID: $0.frameID,
                orderIndex: $0.orderIndex,
                isKeyFrame: $0.isKeyFrame
            )
        }

        let applyReport = client.run(
            frames: clientFrames,
            keyFrameIDs: keyFrameIDs,
            canvasWidth: canvasWidth,
            canvasHeight: canvasHeight
        )

        return TrackingRunReport(
            resolvedCorrespondenceCount: applyReport.resolvedCorrespondenceCount,
            processedFrameCount: applyReport.processedFrameCount,
            processedFrameIDs: processedFrameIDs,
            kernelExecuted: applyReport.kernelExecuted
        )
    }

    /// Builds the user-visible feedback string for a tracking run report.
    public static func feedbackMessage(for report: TrackingRunReport) -> String {
        guard report.kernelExecuted else {
            return "\(report.processedFrameCount) frames in cut, tracking kernel not yet available"
        }
        return "\(report.processedFrameCount) frames processed, \(report.resolvedCorrespondenceCount) correspondences resolved"
    }
}

// MARK: - Protocol for testability

/// Internal frame input type used to hand data to the client protocol.
/// Not a public exported type — callers use TrackingFrameDescriptor.
public struct TrackingCoordinatorFrameInput: Equatable, Sendable {
    public let frameID: UUID
    public let orderIndex: Int
    public let isKeyFrame: Bool

    public init(frameID: UUID, orderIndex: Int, isKeyFrame: Bool) {
        self.frameID = frameID
        self.orderIndex = orderIndex
        self.isKeyFrame = isKeyFrame
    }
}

/// Return type from the client protocol — mirrors TrackingApplyReport
/// without requiring a direct import of ColorAnimaAppEngine in this target.
public struct TrackingCoordinatorApplyReport: Equatable, Sendable {
    public let resolvedCorrespondenceCount: Int
    public let processedFrameCount: Int
    public let kernelExecuted: Bool

    public init(resolvedCorrespondenceCount: Int, processedFrameCount: Int, kernelExecuted: Bool) {
        self.resolvedCorrespondenceCount = resolvedCorrespondenceCount
        self.processedFrameCount = processedFrameCount
        self.kernelExecuted = kernelExecuted
    }
}

/// Protocol that TrackingClient (AppEngine layer) conforms to,
/// allowing the coordinator to be tested with a stub client.
public protocol TrackingClientProtocol: Sendable {
    func run(
        frames: [TrackingCoordinatorFrameInput],
        keyFrameIDs: Set<UUID>,
        canvasWidth: Int,
        canvasHeight: Int
    ) -> TrackingCoordinatorApplyReport
}
