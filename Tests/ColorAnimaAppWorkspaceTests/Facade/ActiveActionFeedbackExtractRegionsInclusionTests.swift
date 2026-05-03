import ColorAnimaAppWorkspaceApplication
import Testing
@testable import ColorAnimaAppWorkspace


@Suite("ActiveActionFeedbackSelector — extractRegions inclusion")
@MainActor
struct ActiveActionFeedbackExtractRegionsInclusionTests {

    /// An extract-regions feedback that is `.running` must be selected by the
    /// active-action-feedback selector so it surfaces in the status strip.
    @Test("selector surfaces extractRegions feedback when running")
    func selectorSurfacesExtractRegionsFeedbackWhenRunning() {
        let extractRegionsFeedback = LongRunningActionFeedback(actionLabel: "Extract Regions")

        // All feedbacks are .queued at birth — nothing active yet.
        #expect(ActiveActionFeedbackSelector.select(from: [extractRegionsFeedback]) == nil)

        // Transition to .running — it must now be selected.
        extractRegionsFeedback.markRunning()

        let active = ActiveActionFeedbackSelector.select(from: [extractRegionsFeedback])
        #expect(active === extractRegionsFeedback)
    }

    /// When extractRegions feedback is `.completed` it still qualifies — the
    /// terminal state is surfaced so the user can see the outcome in the strip.
    @Test("selector surfaces extractRegions feedback when completed")
    func selectorSurfacesExtractRegionsFeedbackWhenCompleted() {
        let extractRegionsFeedback = LongRunningActionFeedback(actionLabel: "Extract Regions")

        extractRegionsFeedback.markRunning()
        extractRegionsFeedback.markCompleted()

        let active = ActiveActionFeedbackSelector.select(from: [extractRegionsFeedback])
        #expect(active === extractRegionsFeedback)
    }

    /// `.failed` is excluded — the error channel is the alert, not the strip.
    @Test("selector excludes extractRegions feedback when failed")
    func selectorExcludesExtractRegionsFeedbackWhenFailed() {
        let extractRegionsFeedback = LongRunningActionFeedback(actionLabel: "Extract Regions")

        extractRegionsFeedback.markRunning()
        extractRegionsFeedback.markFailed(message: "boom")

        #expect(ActiveActionFeedbackSelector.select(from: [extractRegionsFeedback]) == nil)
    }

    /// A running feedback takes priority over any terminal feedback in the list.
    @Test("running feedback wins over completed feedback in priority order")
    func runningFeedbackWinsOverCompleted() {
        let completedFeedback = LongRunningActionFeedback(actionLabel: "Previous Action")
        completedFeedback.markRunning()
        completedFeedback.markCompleted()

        let runningFeedback = LongRunningActionFeedback(actionLabel: "Extract Regions")
        runningFeedback.markRunning()

        let active = ActiveActionFeedbackSelector.select(from: [completedFeedback, runningFeedback])
        #expect(active === runningFeedback)
    }
}
