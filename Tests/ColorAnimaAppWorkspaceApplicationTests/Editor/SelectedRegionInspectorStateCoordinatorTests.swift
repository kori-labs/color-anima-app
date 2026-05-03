import CoreGraphics
import XCTest
@testable import ColorAnimaAppWorkspaceApplication

final class SelectedRegionInspectorStateCoordinatorTests: XCTestCase {
    func testTrackingStateSummaryMapsAllTrackingStates() throws {
        let cases: [(ConfidenceReviewState, String)] = [
            (.tracked, "Tracking: Tracked"),
            (.reviewNeeded, "Tracking: Review Needed"),
            (.unresolved, "Tracking: Unresolved"),
        ]

        for (trackingState, expectedSummary) in cases {
            let result = try XCTUnwrap(
                SelectedRegionInspectorStateCoordinator.makeState(
                    region: makeRegion(),
                    groups: [],
                    selectedSubsetID: nil,
                    trackingRecord: SelectedRegionTrackingRecord(state: trackingState)
                )
            )

            XCTAssertEqual(result.trackingStateSummary, expectedSummary)
        }
    }

    func testInspectorProjectionReflectsAssignmentAndSplitSummaries() throws {
        let groupID = UUID()
        let subsetID = UUID()
        let region = makeRegion(
            assignment: SelectedRegionAssignment(
                groupID: groupID,
                subsetID: subsetID,
                highlightSplitDecision: .inverted,
                shadowSplitDecision: .normal
            )
        )
        let groups = [
            ColorSystemGroup(
                id: groupID,
                name: "Character",
                subsets: [
                    ColorSystemSubset(name: "Skin", palettes: [])
                ]
            )
        ]
        let adjustedGroups = [
            ColorSystemGroup(
                id: groupID,
                name: "Character",
                subsets: [
                    ColorSystemSubset(id: subsetID, name: "Skin", palettes: [])
                ]
            )
        ]

        XCTAssertNil(
            SelectedRegionInspectorStateCoordinator.makeState(
                region: region,
                groups: groups,
                selectedSubsetID: subsetID
            )?.highlightSplitSummary
        )

        let result = try XCTUnwrap(
            SelectedRegionInspectorStateCoordinator.makeState(
                region: region,
                groups: adjustedGroups,
                selectedSubsetID: subsetID
            )
        )

        XCTAssertEqual(result.assignmentSummary, "Assigned to Character / Skin")
        XCTAssertEqual(result.highlightSplitSummary, "Highlight Split: Inverted")
        XCTAssertEqual(result.shadowSplitSummary, "Shadow Split: Normal")
        XCTAssertTrue(result.canAssignToSelectedSubset)
        XCTAssertTrue(result.canClearAssignment)
        XCTAssertTrue(result.canInvertHighlightSplit)
        XCTAssertTrue(result.canInvertShadowSplit)
    }

    func testInspectorProjectionReflectsTrackingConfidenceReasonAndManualState() throws {
        let result = try XCTUnwrap(
            SelectedRegionInspectorStateCoordinator.makeState(
                region: makeRegion(),
                groups: [],
                selectedSubsetID: UUID(),
                trackingRecord: SelectedRegionTrackingRecord(
                    state: .reviewNeeded,
                    confidenceValue: 0.75,
                    reasonCodes: [.lowMargin, .structuralConflict],
                    isManualCorrection: true,
                    hasResolvedAssignment: true
                )
            )
        )

        XCTAssertEqual(result.trackingStateSummary, "Tracking: Review Needed")
        XCTAssertEqual(result.trackingConfidenceSummary, "Confidence 75%")
        XCTAssertEqual(result.trackingReasonSummary, "Low margin, Structural conflict")
        XCTAssertEqual(result.trackingManualSummary, "Manual correction preserved")
        XCTAssertTrue(result.isTrackingAware)
        XCTAssertEqual(result.assignActionTitle, "Reassign to Selected Subset")
        XCTAssertEqual(result.clearActionTitle, "Mark Unresolved")
        XCTAssertFalse(result.canAcceptTracking)
        XCTAssertFalse(result.canReassignTracking)
        XCTAssertTrue(result.canClearTracking)
    }

    func testAcceptTrackingRequiresResolvedNonManualAssignment() throws {
        let unresolved = try XCTUnwrap(
            SelectedRegionInspectorStateCoordinator.makeState(
                region: makeRegion(),
                groups: [],
                selectedSubsetID: nil,
                trackingRecord: SelectedRegionTrackingRecord(
                    state: .reviewNeeded,
                    hasResolvedAssignment: false
                )
            )
        )

        let resolved = try XCTUnwrap(
            SelectedRegionInspectorStateCoordinator.makeState(
                region: makeRegion(),
                groups: [],
                selectedSubsetID: nil,
                trackingRecord: SelectedRegionTrackingRecord(
                    state: .reviewNeeded,
                    hasResolvedAssignment: true
                )
            )
        )

        XCTAssertFalse(unresolved.canAcceptTracking)
        XCTAssertTrue(resolved.canAcceptTracking)
    }

    func testBackgroundCandidateDisablesBoundaryEditing() throws {
        let result = try XCTUnwrap(
            SelectedRegionInspectorStateCoordinator.makeState(
                region: makeRegion(isBackgroundCandidate: true, boundaryOffset: 3),
                groups: [],
                selectedSubsetID: nil
            )
        )

        XCTAssertEqual(result.assignmentSummary, "Background candidate")
        XCTAssertEqual(result.boundaryOffset, 3)
        XCTAssertFalse(result.canEditBoundaryOffset)
    }

    func testReturnsNilWhenNoRegionIsSelected() {
        XCTAssertNil(
            SelectedRegionInspectorStateCoordinator.makeState(
                region: nil,
                groups: [],
                selectedSubsetID: nil
            )
        )
    }

    private func makeRegion(
        id: UUID = UUID(),
        assignment: SelectedRegionAssignment? = nil,
        isBackgroundCandidate: Bool = false,
        boundaryOffset: Int = 0
    ) -> SelectedRegionInspectorRegion {
        SelectedRegionInspectorRegion(
            id: id,
            displayName: "Test Region",
            centroid: CGPoint(x: 3.6, y: 4.4),
            bounds: CGRect(x: 2, y: 3, width: 5, height: 7),
            assignment: assignment,
            isBackgroundCandidate: isBackgroundCandidate,
            boundaryOffset: boundaryOffset
        )
    }
}
