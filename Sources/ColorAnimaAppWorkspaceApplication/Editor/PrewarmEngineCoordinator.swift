// PrewarmEngineCoordinator.swift
// Layer: ColorAnimaAppWorkspaceApplication — orchestration on top of the AppEngine client.
//
// Replaces the deleted CutWorkspacePreviewPrewarmEngine + CutWorkspacePreviewPrewarmComputation
// (source-only, imported the kernel-internal implementation, imaging, and domain targets).
//
// All logic is expressed in terms of public DTOs. The coordinator schedules
// prewarm passes, runs the AppEngine client, and returns effect descriptors
// that the call site applies to its own model. It never holds or mutates
// workspace state directly.
//
// The coordinator is intentionally UI-free and MainActor-free to preserve
// RenderCore portability conventions.

import Foundation

// MARK: - Public input DTOs

/// Priority tiers for prewarm scheduling.
///
/// Mirrors the deleted CutWorkspacePreviewPrewarmEngine.PrewarmPriority enum,
/// expressed as a public DTO without source-only dependencies.
public enum PrewarmSchedulePriority: Equatable, Sendable {
    /// Highest priority.
    case high
    /// Medium priority.
    case medium
    /// Lowest priority.
    case low
}

/// A single frame descriptor passed into the prewarm coordinator.
public struct PrewarmFrameDescriptor: Equatable, Sendable {
    public let frameID: UUID
    public let orderIndex: Int

    public init(frameID: UUID, orderIndex: Int) {
        self.frameID = frameID
        self.orderIndex = orderIndex
    }
}

/// Canvas geometry passed to the prewarm coordinator.
public struct PrewarmCanvasDescriptor: Equatable, Sendable {
    public let width: Int
    public let height: Int

    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }
}

// MARK: - Effect descriptor returned to call site

/// Per-frame outcome returned to the call site after a prewarm pass.
public struct PrewarmFrameEffect: Equatable, Sendable {
    public let frameID: UUID
    /// Whether preview state was computed for this frame in this pass.
    public let previewStateComputed: Bool

    public init(frameID: UUID, previewStateComputed: Bool) {
        self.frameID = frameID
        self.previewStateComputed = previewStateComputed
    }
}

/// Aggregate effect descriptor returned by PrewarmEngineCoordinator to the call site.
public struct PrewarmEffect: Equatable, Sendable {
    /// Per-frame outcomes for frames that were included in the pass.
    public let frameEffects: [PrewarmFrameEffect]
    /// Number of frames for which preview state was computed.
    public let computedFrameCount: Int
    /// Whether the kernel executed the pass.
    public let kernelExecuted: Bool

    public init(
        frameEffects: [PrewarmFrameEffect],
        computedFrameCount: Int,
        kernelExecuted: Bool
    ) {
        self.frameEffects = frameEffects
        self.computedFrameCount = computedFrameCount
        self.kernelExecuted = kernelExecuted
    }
}

// MARK: - Coordinator

/// Orchestrates background prewarm execution over an app-side AppEngine client.
///
/// All logic is expressed in terms of public DTOs. The coordinator builds
/// prewarm requests, invokes the client, and returns effect descriptors that
/// the call site applies to its own model state. It never holds or mutates
/// workspace state.
///
/// The active frame is always excluded from prewarm: pass `selectedFrameID`
/// so the coordinator can filter it before dispatching to the client.
public enum PrewarmEngineCoordinator {

    // MARK: - Single-cut prewarm

    /// Runs a prewarm pass for the supplied frames via the AppEngine client.
    ///
    /// Returns a PrewarmEffect with kernelExecuted = false when the kernel C
    /// function is not yet exposed. The call site decides how to handle the
    /// unavailable case (e.g. fall back to Swift-only path, no-op).
    ///
    /// - Parameters:
    ///   - frames: All frame descriptors in the cut, ordered by orderIndex.
    ///   - selectedFrameID: Currently selected frame; excluded from the prewarm pass.
    ///   - canvas: Canvas geometry.
    ///   - priority: Scheduling priority tier.
    ///   - client: AppEngine client to delegate the Bridge call to.
    public static func prewarm(
        frames: [PrewarmFrameDescriptor],
        selectedFrameID: UUID?,
        canvas: PrewarmCanvasDescriptor,
        priority: PrewarmSchedulePriority,
        client: PrewarmClientProtocol
    ) -> PrewarmEffect {
        let inactiveFrames = frames.filter { $0.frameID != selectedFrameID }
        guard !inactiveFrames.isEmpty else {
            return PrewarmEffect(frameEffects: [], computedFrameCount: 0, kernelExecuted: false)
        }
        guard canvas.width > 0, canvas.height > 0 else {
            return PrewarmEffect(frameEffects: [], computedFrameCount: 0, kernelExecuted: false)
        }

        let clientFrames = inactiveFrames.map {
            PrewarmCoordinatorFrameInput(frameID: $0.frameID, orderIndex: $0.orderIndex)
        }
        let report = client.run(
            frames: clientFrames,
            canvasWidth: canvas.width,
            canvasHeight: canvas.height,
            priorityTier: coordinatorPriorityTier(from: priority)
        )

        let frameEffects = inactiveFrames.map { frame in
            PrewarmFrameEffect(
                frameID: frame.frameID,
                previewStateComputed: report.kernelExecuted
            )
        }

        return PrewarmEffect(
            frameEffects: frameEffects,
            computedFrameCount: report.computedFrameCount,
            kernelExecuted: report.kernelExecuted
        )
    }

    // MARK: - Active-frame guard

    /// Whether the prewarm pass should skip the active frame.
    ///
    /// Always true — the active frame is never added to the prewarm cache;
    /// the selected frame's preview is managed directly by the preview coordinator.
    public static func shouldExcludeActiveFrame(_ frameID: UUID, selectedFrameID: UUID?) -> Bool {
        frameID == selectedFrameID
    }

    // MARK: - Feedback

    /// Builds the user-visible feedback string for a prewarm effect.
    public static func feedbackMessage(for effect: PrewarmEffect) -> String {
        guard effect.kernelExecuted else {
            return "\(effect.frameEffects.count) frames queued, prewarm kernel not yet available"
        }
        return "\(effect.computedFrameCount) frames prewarmed"
    }

    // MARK: - Private helpers

    private static func coordinatorPriorityTier(
        from priority: PrewarmSchedulePriority
    ) -> PrewarmCoordinatorPriorityTier {
        switch priority {
        case .high:   return .high
        case .medium: return .medium
        case .low:    return .low
        }
    }
}

// MARK: - Protocol for testability

/// Internal frame input type handed to the client protocol.
/// Not exported as a standalone public type — callers use PrewarmFrameDescriptor.
public struct PrewarmCoordinatorFrameInput: Equatable, Sendable {
    public let frameID: UUID
    public let orderIndex: Int

    public init(frameID: UUID, orderIndex: Int) {
        self.frameID = frameID
        self.orderIndex = orderIndex
    }
}

/// Priority tier type used in the client protocol.
public enum PrewarmCoordinatorPriorityTier: Equatable, Sendable {
    case high
    case medium
    case low
}

/// Return type from the client protocol — mirrors PrewarmApplyReport without
/// requiring a direct import of ColorAnimaAppEngine in this target.
public struct PrewarmCoordinatorApplyReport: Equatable, Sendable {
    public let computedFrameCount: Int
    public let kernelExecuted: Bool

    public init(computedFrameCount: Int, kernelExecuted: Bool) {
        self.computedFrameCount = computedFrameCount
        self.kernelExecuted = kernelExecuted
    }
}

/// Protocol that PrewarmClient (AppEngine layer) conforms to,
/// allowing the coordinator to be tested with a stub client.
public protocol PrewarmClientProtocol: Sendable {
    func run(
        frames: [PrewarmCoordinatorFrameInput],
        canvasWidth: Int,
        canvasHeight: Int,
        priorityTier: PrewarmCoordinatorPriorityTier
    ) -> PrewarmCoordinatorApplyReport
}
