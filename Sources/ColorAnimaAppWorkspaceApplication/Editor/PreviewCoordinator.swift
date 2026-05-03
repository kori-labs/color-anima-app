// PreviewCoordinator.swift
// Layer: ColorAnimaAppWorkspaceApplication — orchestration on top of the AppEngine client.
//
// Replaces the deleted CutWorkspacePreviewCoordinator (source-only, imported
// the kernel-internal implementation and interface targets).
//
// All logic is expressed in terms of public DTOs. The coordinator derives
// preview rebuild requests, runs the AppEngine client, and returns effect
// descriptors that the call site applies to its own model. It never holds or
// mutates workspace state directly.
//
// The coordinator is intentionally UI-free and MainActor-free: it operates on
// pure value types and delegates all model mutation to the call site via its
// return values.

import Foundation

// MARK: - Public input DTOs

/// A single frame descriptor passed into the coordinator from the call site.
public struct PreviewFrameDescriptor: Equatable, Sendable {
    public let frameID: UUID
    public let orderIndex: Int
    public let hasComputedOverlay: Bool

    public init(frameID: UUID, orderIndex: Int, hasComputedOverlay: Bool) {
        self.frameID = frameID
        self.orderIndex = orderIndex
        self.hasComputedOverlay = hasComputedOverlay
    }
}

/// Canvas geometry passed to the coordinator from the call site.
public struct PreviewCanvasDescriptor: Equatable, Sendable {
    public let width: Int
    public let height: Int

    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }
}

// MARK: - Effect descriptor returned to call site

/// Effect descriptor returned by PreviewCoordinator to the call site.
///
/// The call site inspects these flags and applies mutations to its own model.
/// Nothing in the coordinator mutates observable state directly.
public struct PreviewRebuildEffect: Equatable, Sendable {
    /// Number of frames for which overlays were computed.
    public let computedFrameCount: Int
    /// Whether the kernel executed the pass.
    public let kernelExecuted: Bool
    /// Whether line preview images should be marked dirty at the call site.
    public let linePreviewImagesDirty: Bool

    public init(
        computedFrameCount: Int,
        kernelExecuted: Bool,
        linePreviewImagesDirty: Bool
    ) {
        self.computedFrameCount = computedFrameCount
        self.kernelExecuted = kernelExecuted
        self.linePreviewImagesDirty = linePreviewImagesDirty
    }
}

// MARK: - Coordinator

/// Orchestrates preview rebuild over an app-side AppEngine client.
///
/// All logic is expressed in terms of public DTOs. The coordinator builds
/// render requests, invokes the client, and returns effect descriptors that
/// the call site applies to its own model state. It never holds or mutates
/// workspace state.
public enum PreviewCoordinator {

    // MARK: - Rebuild

    /// Runs a preview rebuild pass via the supplied AppEngine client.
    ///
    /// Returns a PreviewRebuildEffect with kernelExecuted = false when the
    /// kernel C function is not yet exposed. The call site decides how to
    /// handle the unavailable case (e.g. fall back to Swift-only path, log).
    ///
    /// - Parameters:
    ///   - frames: Frame descriptors for the current cut, ordered by orderIndex.
    ///   - canvas: Canvas geometry.
    ///   - selectedFrameID: Currently selected frame identifier.
    ///   - client: AppEngine client to delegate the Bridge call to.
    public static func rebuild(
        frames: [PreviewFrameDescriptor],
        canvas: PreviewCanvasDescriptor,
        selectedFrameID: UUID?,
        client: PreviewRenderClientProtocol
    ) -> PreviewRebuildEffect {
        let clientFrames = frames.map {
            PreviewCoordinatorFrameInput(
                frameID: $0.frameID,
                orderIndex: $0.orderIndex,
                hasComputedOverlay: $0.hasComputedOverlay
            )
        }
        let report = client.run(
            frames: clientFrames,
            canvasWidth: canvas.width,
            canvasHeight: canvas.height,
            selectedFrameID: selectedFrameID
        )
        return PreviewRebuildEffect(
            computedFrameCount: report.computedFrameCount,
            kernelExecuted: report.kernelExecuted,
            linePreviewImagesDirty: !report.kernelExecuted
        )
    }

    /// Builds the user-visible feedback string for a rebuild effect.
    public static func feedbackMessage(for effect: PreviewRebuildEffect) -> String {
        guard effect.kernelExecuted else {
            return "Preview rebuild: kernel not yet available"
        }
        return "\(effect.computedFrameCount) frame overlays updated"
    }
}

// MARK: - Internal frame input type (not a public exported type)

/// Internal frame input type handed to the client protocol.
/// Not exported as a standalone public type — callers use PreviewFrameDescriptor.
public struct PreviewCoordinatorFrameInput: Equatable, Sendable {
    public let frameID: UUID
    public let orderIndex: Int
    public let hasComputedOverlay: Bool

    public init(frameID: UUID, orderIndex: Int, hasComputedOverlay: Bool) {
        self.frameID = frameID
        self.orderIndex = orderIndex
        self.hasComputedOverlay = hasComputedOverlay
    }
}

/// Return type from the client protocol — mirrors PreviewRenderReport without
/// requiring a direct import of ColorAnimaAppEngine in this target.
public struct PreviewCoordinatorRenderReport: Equatable, Sendable {
    public let computedFrameCount: Int
    public let kernelExecuted: Bool

    public init(computedFrameCount: Int, kernelExecuted: Bool) {
        self.computedFrameCount = computedFrameCount
        self.kernelExecuted = kernelExecuted
    }
}

/// Protocol that PreviewRenderClient (AppEngine layer) conforms to,
/// allowing the coordinator to be tested with a stub client.
public protocol PreviewRenderClientProtocol: Sendable {
    func run(
        frames: [PreviewCoordinatorFrameInput],
        canvasWidth: Int,
        canvasHeight: Int,
        selectedFrameID: UUID?
    ) -> PreviewCoordinatorRenderReport
}
