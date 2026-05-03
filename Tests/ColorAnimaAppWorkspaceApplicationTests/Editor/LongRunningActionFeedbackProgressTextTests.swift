import Foundation
import Testing
@testable import ColorAnimaAppWorkspaceApplication

@Suite("LongRunningActionFeedback progress text")
@MainActor
struct LongRunningActionFeedbackProgressTextTests {

    @Test("progressText defaults to nil")
    func progressTextDefaultsToNil() {
        let feedback = LongRunningActionFeedback(actionLabel: "Extract Regions")
        #expect(feedback.progressText == nil)
    }

    @Test("progressText is mutable across state transitions")
    func progressTextMutableAcrossTransitions() {
        let feedback = LongRunningActionFeedback(actionLabel: "Extract Regions")
        feedback.markRunning()
        feedback.progressText = "Extracting Regions (1/2)"
        #expect(feedback.progressText == "Extracting Regions (1/2)")

        feedback.progressText = "Warming up Frames (2/2)"
        #expect(feedback.progressText == "Warming up Frames (2/2)")
    }

    @Test("progressText is cleared when feedback transitions to completed")
    func progressTextClearedOnCompleted() {
        let feedback = LongRunningActionFeedback(actionLabel: "Extract Regions")
        feedback.markRunning()
        feedback.progressText = "Warming up Frames (2/2)"
        feedback.markCompleted()
        #expect(feedback.progressText == nil)
    }

    @Test("progressText is cleared when feedback transitions to failed")
    func progressTextClearedOnFailed() {
        let feedback = LongRunningActionFeedback(actionLabel: "Extract Regions")
        feedback.markRunning()
        feedback.progressText = "Extracting Regions (1/2)"
        feedback.markFailed(message: "boom")
        #expect(feedback.progressText == nil)
    }

    @Test("progressText is cleared when feedback transitions to cancelled")
    func progressTextClearedOnCancelled() {
        let feedback = LongRunningActionFeedback(actionLabel: "Multi-image Import")
        let handle = LongRunningActionCancelHandle(onCancel: {})
        feedback.markRunning(cancelHandle: handle)
        feedback.progressText = "Importing (3/10)"
        feedback.markCancelled()
        #expect(feedback.progressText == nil)
    }

    @Test("late emitter from first run does not mutate second-run feedback")
    func lateEmitterDoesNotMutateSecondRunFeedback() {
        let firstFeedback = LongRunningActionFeedback(actionLabel: "Preview rebuild")
        firstFeedback.markRunning()
        let firstEmitter: (String?) -> Void = { [weak firstFeedback] text in
            firstFeedback?.progressText = text
        }

        let secondFeedback = LongRunningActionFeedback(actionLabel: "Preview rebuild")
        secondFeedback.markRunning()

        firstEmitter("stale progress from cancelled task")

        #expect(secondFeedback.progressText == nil)
        #expect(firstFeedback.progressText == "stale progress from cancelled task")
    }

    @Test("captured emitter writes to its own feedback instance")
    func capturedEmitterWritesToOwnFeedback() {
        let feedback = LongRunningActionFeedback(actionLabel: "Preview rebuild")
        feedback.markRunning()
        let emitter: (String?) -> Void = { [weak feedback] text in
            feedback?.progressText = text
        }

        emitter("Three-frame prewarm: 1/3")

        #expect(feedback.progressText == "Three-frame prewarm: 1/3")
    }

    @Test("nil teardown from first emitter does not clear second-run feedback")
    func nilTeardownDoesNotClearSecondRunFeedback() {
        let firstFeedback = LongRunningActionFeedback(actionLabel: "Preview rebuild")
        firstFeedback.markRunning()
        let firstEmitter: (String?) -> Void = { [weak firstFeedback] text in
            firstFeedback?.progressText = text
        }

        let secondFeedback = LongRunningActionFeedback(actionLabel: "Preview rebuild")
        secondFeedback.markRunning()
        secondFeedback.progressText = "Three-frame prewarm: 2/3"

        firstEmitter(nil)

        #expect(secondFeedback.progressText == "Three-frame prewarm: 2/3")
    }
}
