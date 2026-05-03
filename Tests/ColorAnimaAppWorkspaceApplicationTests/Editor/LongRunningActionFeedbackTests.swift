import Foundation
import Testing
@testable import ColorAnimaAppWorkspaceApplication

@Suite("LongRunningActionFeedback state transitions")
@MainActor
struct LongRunningActionFeedbackTests {

    @Test("Initial state is queued")
    func initialStateIsQueued() {
        let feedback = LongRunningActionFeedback(actionLabel: "Run Tracking")
        #expect(feedback.state == .queued)
        #expect(feedback.startedAt == nil)
        #expect(feedback.isCancellable == false)
        #expect(feedback.isTerminal == false)
    }

    @Test("queued to running records startedAt and is non-cancellable when no handle is given")
    func queuedToRunningWithoutHandle() {
        let feedback = LongRunningActionFeedback(actionLabel: "Extract Regions")
        feedback.markRunning()
        #expect(feedback.state == .running)
        #expect(feedback.startedAt != nil)
        #expect(feedback.isCancellable == false)
        #expect(feedback.isTerminal == false)
    }

    @Test("queued to running with cancel handle marks action as cancellable")
    func queuedToRunningWithHandle() {
        let feedback = LongRunningActionFeedback(actionLabel: "Multi-image Import")
        let handle = LongRunningActionCancelHandle(onCancel: {})
        feedback.markRunning(cancelHandle: handle)
        #expect(feedback.state == .running)
        #expect(feedback.isCancellable == true)
    }

    @Test("running to completed is terminal and clears cancel handle")
    func runningToCompleted() {
        let feedback = LongRunningActionFeedback(actionLabel: "Extract Frames")
        let handle = LongRunningActionCancelHandle(onCancel: {})
        feedback.markRunning(cancelHandle: handle)
        feedback.markCompleted()
        #expect(feedback.state == .completed)
        #expect(feedback.isCancellable == false)
        #expect(feedback.isTerminal == true)
    }

    @Test("running to failed carries error message and is terminal")
    func runningToFailed() {
        let feedback = LongRunningActionFeedback(actionLabel: "Run Tracking")
        feedback.markRunning()
        feedback.markFailed(message: "Tracking data unavailable.")
        if case .failed(let msg) = feedback.state {
            #expect(msg == "Tracking data unavailable.")
        } else {
            Issue.record("Expected .failed state, got \(feedback.state)")
        }
        #expect(feedback.isTerminal == true)
    }

    @Test("running to cancelled invokes the cancel handle and is terminal")
    func runningToCancelled() {
        @MainActor
        final class CancelFlag { var called = false }
        let flag = CancelFlag()
        let feedback = LongRunningActionFeedback(actionLabel: "Multi-image Import")
        let handle = LongRunningActionCancelHandle(onCancel: {
            MainActor.assumeIsolated {
                flag.called = true
            }
        })
        feedback.markRunning(cancelHandle: handle)
        feedback.markCancelled()
        #expect(feedback.state == .cancelled)
        #expect(flag.called == true)
        #expect(feedback.isCancellable == false)
        #expect(feedback.isTerminal == true)
    }

    @Test("completed feedback remains terminal and requires a fresh instance")
    func completedIsTerminalAndRequiresFreshInstance() {
        let feedback = LongRunningActionFeedback(actionLabel: "Extract Regions")
        feedback.markRunning()
        feedback.markCompleted()
        #expect(feedback.isTerminal == true)
        #expect(feedback.state == .completed)
    }

    @Test("failed state is terminal")
    func failedIsTerminal() {
        let feedback = LongRunningActionFeedback(actionLabel: "Extract Frames")
        feedback.markRunning()
        feedback.markFailed(message: "Missing outline artwork.")
        #expect(feedback.isTerminal == true)
    }

    @Test("cancelled state is terminal")
    func cancelledIsTerminal() {
        let feedback = LongRunningActionFeedback(actionLabel: "Multi-image Import")
        let handle = LongRunningActionCancelHandle(onCancel: {})
        feedback.markRunning(cancelHandle: handle)
        feedback.markCancelled()
        #expect(feedback.isTerminal == true)
    }

    @Test("hasExceededQuietThreshold is false before markRunning")
    func thresholdFalseBeforeRunning() {
        let feedback = LongRunningActionFeedback(actionLabel: "Preview rebuild")
        #expect(feedback.hasExceededQuietThreshold == false)
    }

    @Test("hasExceededQuietThreshold is true when threshold is zero and running")
    func thresholdTrueWhenZeroAndRunning() {
        LongRunningActionFeedback._quietThresholdSecondsOverride = 0
        defer { LongRunningActionFeedback._quietThresholdSecondsOverride = nil }

        let feedback = LongRunningActionFeedback(actionLabel: "Preview rebuild")
        feedback.markRunning()
        #expect(feedback.hasExceededQuietThreshold == true)
    }

    @Test("hasExceededQuietThreshold is false when threshold is far in the future")
    func thresholdFalseWhenThresholdLarge() {
        LongRunningActionFeedback._quietThresholdSecondsOverride = 9999
        defer { LongRunningActionFeedback._quietThresholdSecondsOverride = nil }

        let feedback = LongRunningActionFeedback(actionLabel: "Preview rebuild")
        feedback.markRunning()
        #expect(feedback.hasExceededQuietThreshold == false)
    }

    @Test("actionLabel is preserved across transitions")
    func actionLabelPreserved() {
        let label = "Reference Frame Update"
        let feedback = LongRunningActionFeedback(actionLabel: label)
        feedback.markRunning()
        feedback.markCompleted()
        #expect(feedback.actionLabel == label)
    }

    @Test("captured completion guard ignores replaced feedback instance")
    func capturedCompletionGuardIgnoresReplacedFeedback() {
        let firstFeedback = LongRunningActionFeedback(actionLabel: "Reference Frame Update")
        let secondFeedback = LongRunningActionFeedback(actionLabel: "Reference Frame Update")

        firstFeedback.markRunning()
        secondFeedback.markRunning()

        let capturedFeedback = firstFeedback
        let currentFeedback = secondFeedback
        let shouldComplete = shouldCompleteCapturedFeedback(
            current: currentFeedback,
            captured: capturedFeedback,
            isCancelled: false
        )

        #expect(shouldComplete == false)
        #expect(firstFeedback.state == .running)
        #expect(secondFeedback.state == .running)
    }

    @Test("captured completion guard completes current nonterminal feedback")
    func capturedCompletionGuardCompletesCurrentFeedback() {
        let feedback = LongRunningActionFeedback(actionLabel: "Reference Frame Update")
        feedback.markRunning()

        let shouldComplete = shouldCompleteCapturedFeedback(
            current: feedback,
            captured: feedback,
            isCancelled: false
        )

        if shouldComplete {
            feedback.markCompleted()
        }

        #expect(feedback.state == .completed)
    }

    @Test("captured completion guard ignores cancelled or terminal feedback")
    func capturedCompletionGuardIgnoresCancelledOrTerminalFeedback() {
        let cancelledFeedback = LongRunningActionFeedback(actionLabel: "Reference Frame Update")
        cancelledFeedback.markRunning()

        #expect(
            shouldCompleteCapturedFeedback(
                current: cancelledFeedback,
                captured: cancelledFeedback,
                isCancelled: true
            ) == false
        )

        let completedFeedback = LongRunningActionFeedback(actionLabel: "Reference Frame Update")
        completedFeedback.markRunning()
        completedFeedback.markCompleted()

        #expect(
            shouldCompleteCapturedFeedback(
                current: completedFeedback,
                captured: completedFeedback,
                isCancelled: false
            ) == false
        )
    }

    @Test("isCancellable is false when completed even if handle was provided during run")
    func isCancellableFalseAfterCompletion() {
        let feedback = LongRunningActionFeedback(actionLabel: "Multi-image Import")
        let handle = LongRunningActionCancelHandle(onCancel: {})
        feedback.markRunning(cancelHandle: handle)
        feedback.markCompleted()
        #expect(feedback.isCancellable == false)
    }

    private func shouldCompleteCapturedFeedback(
        current: LongRunningActionFeedback,
        captured: LongRunningActionFeedback,
        isCancelled: Bool
    ) -> Bool {
        !isCancelled && current === captured && captured.isTerminal == false
    }
}
