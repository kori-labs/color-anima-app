import ColorAnimaAppWorkspaceApplication
import XCTest

final class CutWorkspaceTrackingReferenceAnchorSelectionTests: XCTestCase {
    func testAnchorFrameIDsFollowFrameOrderAndIgnoreUnknownReferences() {
        let first = UUID()
        let second = UUID()
        let third = UUID()

        let selection = CutWorkspaceTrackingReferenceAnchorSelection.makeReferenceAnchorSelection(
            frameOrder: [first, second, third],
            keyFrameIDs: [third, first, UUID()]
        )

        XCTAssertEqual(selection.anchorFrameIDs, [first, third])
        XCTAssertEqual(selection.preferredFrameID, first)
    }

    func testSelectedFrameSelectionAnchorWinsWhenItIsAReferenceFrame() {
        let first = UUID()
        let second = UUID()
        let third = UUID()

        let selection = CutWorkspaceTrackingReferenceAnchorSelection.makeReferenceAnchorSelection(
            frameOrder: [first, second, third],
            keyFrameIDs: [first, second, third],
            selectedFrameSelectionAnchorID: second,
            activeReferenceFrameID: third,
            selectedFrameID: first
        )

        XCTAssertEqual(selection.preferredFrameID, second)
    }

    func testActiveReferenceFrameIsUsedWhenSelectionAnchorIsUnavailable() {
        let first = UUID()
        let second = UUID()
        let third = UUID()

        let selection = CutWorkspaceTrackingReferenceAnchorSelection.makeReferenceAnchorSelection(
            frameOrder: [first, second, third],
            keyFrameIDs: [first, third],
            selectedFrameSelectionAnchorID: second,
            activeReferenceFrameID: third,
            selectedFrameID: first
        )

        XCTAssertEqual(selection.preferredFrameID, third)
    }

    func testSelectedFrameIsUsedWhenHigherPriorityCandidatesAreUnavailable() {
        let first = UUID()
        let second = UUID()
        let third = UUID()

        let selection = CutWorkspaceTrackingReferenceAnchorSelection.makeReferenceAnchorSelection(
            frameOrder: [first, second, third],
            keyFrameIDs: [first],
            selectedFrameSelectionAnchorID: second,
            activeReferenceFrameID: third,
            selectedFrameID: first
        )

        XCTAssertEqual(selection.preferredFrameID, first)
    }

    func testFirstAnchorIsFallbackPreferredFrame() {
        let first = UUID()
        let second = UUID()
        let third = UUID()

        let selection = CutWorkspaceTrackingReferenceAnchorSelection.makeReferenceAnchorSelection(
            frameOrder: [first, second, third],
            keyFrameIDs: [second, third]
        )

        XCTAssertEqual(selection.preferredFrameID, second)
    }

    func testEmptyAnchorsClearPreferredFrame() {
        let selection = CutWorkspaceTrackingReferenceAnchorSelection.makeReferenceAnchorSelection(
            frameOrder: [UUID()],
            keyFrameIDs: []
        )

        XCTAssertTrue(selection.anchorFrameIDs.isEmpty)
        XCTAssertNil(selection.preferredFrameID)
    }
}
