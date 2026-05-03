import ColorAnimaAppWorkspaceApplication
import Foundation

// MARK: - Active action feedback selection

/// Selects the single active feedback from a list of long-running action feedbacks.
///
/// Selection rules (in priority order):
///  1. The first `.running` feedback wins.
///  2. If no feedback is running, the first terminal (`.completed` or `.cancelled`)
///     feedback is shown so the user can see the outcome.
///  3. `.failed` feedbacks are excluded — errors surface through the alert channel.
///  4. `.queued` feedbacks are excluded.
///
/// The extract-regions feedback participates in selection on the same terms as
/// every other long-running feedback: it is surfaced when running or terminal,
/// and excluded when queued or failed.
@MainActor
public enum ActiveActionFeedbackSelector {

    /// Returns the single feedback that should be presented in the status strip,
    /// or `nil` when no feedback is active.
    ///
    /// - Parameter feedbacks: All registered long-running action feedbacks,
    ///   ordered by priority (lower index wins when multiple qualify).
    public static func select(
        from feedbacks: [LongRunningActionFeedback]
    ) -> LongRunningActionFeedback? {
        // First pass: prefer a currently-running feedback.
        if let running = feedbacks.first(where: { $0.state == .running }) {
            return running
        }
        // Second pass: fall back to the first terminal feedback (completed / cancelled).
        return feedbacks.first(where: { feedback in
            switch feedback.state {
            case .completed, .cancelled:
                return true
            case .queued, .running, .failed:
                return false
            }
        })
    }
}
