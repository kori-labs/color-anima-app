import Foundation
import Observation

public final class LongRunningActionCancelHandle: Sendable {
    private let onCancel: @Sendable () -> Void

    public init(onCancel: @Sendable @escaping () -> Void) {
        self.onCancel = onCancel
    }

    public func cancel() {
        onCancel()
    }
}

public enum LongRunningActionState: Equatable, Sendable {
    case queued
    case running
    case completed
    case failed(message: String)
    case cancelled
}

@MainActor
@Observable
public final class LongRunningActionFeedback {
    package static var _quietThresholdSecondsOverride: Double? = nil

    package static var quietThresholdSeconds: Double {
        _quietThresholdSecondsOverride ?? 0.25
    }

    public private(set) var state: LongRunningActionState
    public private(set) var actionLabel: String
    public private(set) var startedAt: Date?
    public private(set) var cancelHandle: LongRunningActionCancelHandle?
    public var progressText: String? = nil

    public init(actionLabel: String) {
        self.actionLabel = actionLabel
        self.state = .queued
        self.startedAt = nil
        self.cancelHandle = nil
    }

    public func markRunning(cancelHandle: LongRunningActionCancelHandle? = nil) {
        guard state == .queued else {
            assertionFailure("markRunning called from non-queued state: \(state)")
            return
        }
        self.cancelHandle = cancelHandle
        self.startedAt = Date()
        self.state = .running
    }

    public func markCompleted() {
        guard state == .running else {
            assertionFailure("markCompleted called from non-running state: \(state)")
            return
        }
        self.cancelHandle = nil
        self.progressText = nil
        self.state = .completed
    }

    public func markFailed(message: String) {
        guard state == .running else {
            assertionFailure("markFailed called from non-running state: \(state)")
            return
        }
        self.cancelHandle = nil
        self.progressText = nil
        self.state = .failed(message: message)
    }

    public func markCancelled() {
        guard state == .running else {
            assertionFailure("markCancelled called from non-running state: \(state)")
            return
        }
        cancelHandle?.cancel()
        self.cancelHandle = nil
        self.progressText = nil
        self.state = .cancelled
    }

    public var isCancellable: Bool {
        guard case .running = state else { return false }
        return cancelHandle != nil
    }

    public var hasExceededQuietThreshold: Bool {
        guard let startedAt else { return false }
        return Date().timeIntervalSince(startedAt) >= Self.quietThresholdSeconds
    }

    public var isTerminal: Bool {
        switch state {
        case .completed, .failed, .cancelled:
            return true
        case .queued, .running:
            return false
        }
    }
}
