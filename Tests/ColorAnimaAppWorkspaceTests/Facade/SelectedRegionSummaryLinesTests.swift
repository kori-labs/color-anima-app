import Foundation
import XCTest
@testable import ColorAnimaAppWorkspace
import ColorAnimaAppWorkspaceApplication

final class SelectedRegionSummaryLinesTests: XCTestCase {
    func testLinesPreserveAssignmentAndSplitSummariesInOrder() {
        let state = makeState(
            assignmentSummary: "Assigned to character / skin",
            highlightSplitSummary: "Highlight Split: Inverted",
            shadowSplitSummary: "Shadow Split: Normal"
        )

        let lines = SelectedRegionSummaryLines.lines(for: state)

        XCTAssertEqual(lines.map(\.text), [
            "Assigned to character / skin",
            "Highlight Split: Inverted",
            "Shadow Split: Normal",
        ])
        XCTAssertEqual(lines.map(\.kind), [.assignment, .detail, .detail])
    }

    func testLinesOmitMissingSplitSummaries() {
        let state = makeState(
            assignmentSummary: "Background candidate",
            highlightSplitSummary: nil,
            shadowSplitSummary: nil
        )

        let lines = SelectedRegionSummaryLines.lines(for: state)

        XCTAssertEqual(lines.map(\.text), ["Background candidate"])
        XCTAssertEqual(lines.map(\.kind), [.assignment])
    }

    func testLinesIncludeTrackingStateAndConfidenceAfterAssignmentDetails() {
        let state = makeState(
            assignmentSummary: "Assigned to character / skin",
            highlightSplitSummary: nil,
            shadowSplitSummary: nil,
            trackingStateSummary: "Tracking: Review Needed",
            trackingConfidenceSummary: "Confidence 63%"
        )

        let lines = SelectedRegionSummaryLines.lines(for: state)

        XCTAssertEqual(lines.map(\.text), [
            "Assigned to character / skin",
            "Tracking: Review Needed",
            "Confidence 63%",
        ])
        XCTAssertEqual(lines.map(\.kind), [.assignment, .detail, .detail])
    }

    func testLinesIncludeTrackingReasonsAndManualCorrections() {
        let state = makeState(
            assignmentSummary: "Assigned to character / skin",
            highlightSplitSummary: nil,
            shadowSplitSummary: nil,
            trackingStateSummary: "Tracking: Review Needed",
            trackingConfidenceSummary: "Confidence 63%",
            trackingReasonSummary: "Low margin, Merge",
            trackingManualSummary: "Manual correction preserved"
        )

        let lines = SelectedRegionSummaryLines.lines(for: state)

        XCTAssertEqual(lines.map(\.text), [
            "Assigned to character / skin",
            "Tracking: Review Needed",
            "Confidence 63%",
            "Reasons: Low margin, Merge",
            "Manual correction preserved",
        ])
        XCTAssertEqual(lines.map(\.kind), [.assignment, .detail, .detail, .detail, .detail])
    }

    private func makeState(
        assignmentSummary: String,
        highlightSplitSummary: String?,
        shadowSplitSummary: String?,
        trackingStateSummary: String? = nil,
        trackingConfidenceSummary: String? = nil,
        trackingReasonSummary: String? = nil,
        trackingManualSummary: String? = nil
    ) -> SelectedRegionInspectorState {
        SelectedRegionInspectorState(
            regionID: UUID(),
            displayName: "Face",
            regionIDSummary: "12345678",
            centroidSummary: "12, 34",
            boundsSummary: "10, 20 / 30x40",
            assignmentSummary: assignmentSummary,
            highlightSplitSummary: highlightSplitSummary,
            shadowSplitSummary: shadowSplitSummary,
            trackingStateSummary: trackingStateSummary,
            trackingConfidenceSummary: trackingConfidenceSummary,
            trackingReasonSummary: trackingReasonSummary,
            trackingManualSummary: trackingManualSummary,
            canAssignToSelectedSubset: true,
            canClearAssignment: true,
            canInvertHighlightSplit: true,
            canInvertShadowSplit: true
        )
    }
}
