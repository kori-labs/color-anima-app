import Foundation

public enum CutWorkspaceTrackingLauncher {
    public enum LaunchPreparation: Hashable, Equatable, Sendable {
        case started
        case cancelledBeforeStart
    }

    @discardableResult
    public static func prepareLaunch(
        in sessionState: inout CutWorkspaceTrackingSessionState?
    ) -> LaunchPreparation {
        if var existingState = sessionState,
           case .idle = existingState.runStatus {
            existingState.runStatus = .cancelled(framesProcessed: 0, framesTotal: 0)
            sessionState = existingState
            return .cancelledBeforeStart
        }

        var launchingState = sessionState ?? CutWorkspaceTrackingSessionState()
        launchingState.runStatus = .launching
        sessionState = launchingState
        return .started
    }

    @discardableResult
    public static func resolveCancelledBeforeRunIfNeeded(
        in sessionState: inout CutWorkspaceTrackingSessionState?
    ) -> Bool {
        guard var currentState = sessionState,
              case .idle = currentState.runStatus else {
            return false
        }

        currentState.runStatus = .cancelled(framesProcessed: 0, framesTotal: 0)
        sessionState = currentState
        return true
    }

    @discardableResult
    public static func markSkippedLaunchIdleIfNeeded(
        in sessionState: inout CutWorkspaceTrackingSessionState?
    ) -> Bool {
        guard var currentState = sessionState,
              case .launching = currentState.runStatus else {
            return false
        }

        currentState.runStatus = .idle
        sessionState = currentState
        return true
    }

    public static func cancelCurrentRun(
        in sessionState: inout CutWorkspaceTrackingSessionState?
    ) {
        guard var currentState = sessionState else {
            return
        }

        currentState.cancelRunIfActive()
        sessionState = currentState
    }
}
