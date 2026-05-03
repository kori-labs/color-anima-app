// TrackingRunCoordinator.swift
// Layer: ColorAnimaAppWorkspaceApplication — run lifecycle orchestration.
//
// This coordinator replaces the deleted source-only tracking run coordinator
// using public DTOs throughout. It does NOT import ColorAnimaKernel,
// ColorAnimaKernelBridge, or any source-only kernel module.
//
// Integration with ProjectSessionCoordinator is done via its public API only:
// incrementRegionRewriteGeneration and applyPartialRePropagationFeedback
// are the session-level hooks used here to surface feedback to callers.
//
// The coordinator is intentionally UI-free and MainActor-free.

import Foundation

// MARK: - Run lifecycle DTOs

/// Status of a tracking run lifecycle managed by TrackingRunCoordinator.
public enum TrackingRunLifecycleStatus: Equatable, Sendable {
    case idle
    case running(message: String)
    case completed(report: TrackingRunReport)
    case failed(message: String)
    case cancelled
}

/// Snapshot of the run lifecycle state maintained by the call site.
public struct TrackingRunState: Equatable, Sendable {
    public var status: TrackingRunLifecycleStatus
    /// Monotonic counter incremented at each new run start to detect stale completions.
    public var generation: Int

    public init(status: TrackingRunLifecycleStatus = .idle, generation: Int = 0) {
        self.status = status
        self.generation = generation
    }
}

/// Input required to start a tracking run.
public struct TrackingRunInput: Equatable, Sendable {
    public let frames: [TrackingFrameDescriptor]
    public let keyFrameIDs: Set<UUID>
    public let canvasWidth: Int
    public let canvasHeight: Int

    public init(
        frames: [TrackingFrameDescriptor],
        keyFrameIDs: Set<UUID>,
        canvasWidth: Int,
        canvasHeight: Int
    ) {
        self.frames = frames
        self.keyFrameIDs = keyFrameIDs
        self.canvasWidth = canvasWidth
        self.canvasHeight = canvasHeight
    }

    /// Whether this input has the minimum requirements to start a run
    /// (at least one reference frame and at least one non-reference frame).
    public var canRun: Bool {
        let hasReference = frames.contains { keyFrameIDs.contains($0.frameID) }
        let hasNonReference = frames.contains { !keyFrameIDs.contains($0.frameID) }
        return hasReference && hasNonReference
    }
}

// MARK: - Coordinator

/// Orchestrates the tracking run lifecycle over public app-side DTOs.
///
/// Manages run-state transitions (idle → running → completed/failed/cancelled)
/// and delegates actual kernel invocation to TrackingCoordinator. Integrates
/// with ProjectSessionCoordinator via its public feedback API to surface
/// run results to session-level state.
///
/// The coordinator never holds mutable state itself — all state is passed
/// in and returned as value types so the call site remains the single owner.
public enum TrackingRunCoordinator {

    // MARK: - Readiness

    /// Returns whether the given input meets the minimum requirements to start a run.
    ///
    /// Returns false with a human-readable reason when the input is insufficient.
    public static func canRun(
        input: TrackingRunInput
    ) -> (canRun: Bool, reason: String?) {
        guard !input.frames.isEmpty else {
            return (false, "No frames available for tracking.")
        }
        guard !input.keyFrameIDs.isEmpty else {
            return (false, "At least one reference frame is required to start tracking.")
        }
        guard input.canRun else {
            return (false, "At least one non-reference frame is required to track.")
        }
        return (true, nil)
    }

    // MARK: - Run

    /// Executes a synchronous tracking run and returns the updated run state.
    ///
    /// Transitions: idle/failed → running → completed/failed.
    /// The call site is responsible for applying the returned state to its model.
    ///
    /// - Parameters:
    ///   - input: The run input snapshot.
    ///   - state: The current run state (mutated and returned).
    ///   - client: The AppEngine client to delegate to.
    /// - Returns: Updated run state after the run attempt.
    public static func run(
        input: TrackingRunInput,
        state: TrackingRunState,
        client: TrackingClientProtocol
    ) -> TrackingRunState {
        let (canRunNow, reason) = canRun(input: input)
        guard canRunNow else {
            var failed = state
            failed.status = .failed(message: reason ?? "Tracking prerequisites not met.")
            return failed
        }

        var running = state
        running.generation += 1
        running.status = .running(message: "Running tracking pipeline\u{2026}")

        let report = TrackingCoordinator.run(
            frames: input.frames,
            keyFrameIDs: input.keyFrameIDs,
            canvasWidth: input.canvasWidth,
            canvasHeight: input.canvasHeight,
            client: client
        )

        var completed = running
        completed.status = .completed(report: report)
        return completed
    }

    // MARK: - Cancellation

    /// Transitions a running state to cancelled.
    ///
    /// No-op if the current status is not .running.
    public static func cancel(state: TrackingRunState) -> TrackingRunState {
        guard case .running = state.status else { return state }
        var cancelled = state
        cancelled.status = .cancelled
        return cancelled
    }

    // MARK: - Session feedback integration

    /// Builds the session-level feedback string from a completed run state.
    ///
    /// Returns nil when the state does not represent a completed run.
    /// The returned string is suitable for passing to
    /// ProjectSessionCoordinator.applyPartialRePropagationFeedback.
    public static func sessionFeedback(for state: TrackingRunState) -> String? {
        guard case .completed(let report) = state.status else { return nil }
        return TrackingCoordinator.feedbackMessage(for: report)
    }
}
