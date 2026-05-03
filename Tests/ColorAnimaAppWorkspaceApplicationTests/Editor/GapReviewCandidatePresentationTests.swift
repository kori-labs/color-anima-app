import ColorAnimaAppWorkspaceApplication
import XCTest

final class GapReviewCandidatePresentationTests: XCTestCase {
    func testReviewStateDisplayTitlesMatchInspectorCopy() {
        XCTAssertEqual(GapReviewCandidateState.pending.displayTitle, "Pending review")
        XCTAssertEqual(GapReviewCandidateState.acceptedSuggested.displayTitle, "Accepted suggested color")
        XCTAssertEqual(GapReviewCandidateState.manualColorApplied.displayTitle, "Manual color applied")
        XCTAssertEqual(GapReviewCandidateState.ignored.displayTitle, "Ignored")
        XCTAssertEqual(GapReviewCandidateState.rejectedSuggestion.displayTitle, "Suggestion rejected")
        XCTAssertEqual(GapReviewCandidateState.resolvedByRepaint.displayTitle, "Resolved by repaint")
    }

    func testCandidatePreservesSuggestedColorAndMetrics() {
        let color = RGBAColor(red: 0.1, green: 0.2, blue: 0.3, alpha: 0.4)
        let candidate = GapReviewCandidatePresentation(
            area: 42,
            pixelCount: 12,
            confidence: 0.82,
            suggestedColor: color,
            reviewState: .pending
        )

        XCTAssertEqual(candidate.area, 42)
        XCTAssertEqual(candidate.pixelCount, 12)
        XCTAssertEqual(candidate.confidence, 0.82)
        XCTAssertEqual(candidate.suggestedColor, color)
        XCTAssertEqual(candidate.reviewState, .pending)
    }
}
