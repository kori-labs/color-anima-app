import XCTest
@testable import ColorAnimaAppWorkspaceShell

final class WorkspaceDetailSplitSizingTests: XCTestCase {
    func testClampedInspectorWidthPreservesDesiredWidthWhenSpaceIsAvailable() {
        let width = WorkspaceDetailSplitSizing.clampedInspectorWidth(
            desired: 360,
            availableWidth: 1100,
            minimumLeadingWidth: 720,
            range: 340 ... 420,
            dividerThickness: 1
        )

        XCTAssertEqual(width, 360)
    }

    func testClampedInspectorWidthHonorsLeadingMinimumBeforeInspectorMaximum() {
        let width = WorkspaceDetailSplitSizing.clampedInspectorWidth(
            desired: 420,
            availableWidth: 1100,
            minimumLeadingWidth: 720,
            range: 340 ... 420,
            dividerThickness: 1
        )

        XCTAssertEqual(width, 379)
    }

    func testConstrainedLeadingPositionClampsDraggedDividerIntoAllowedBand() {
        let leadingWidth = WorkspaceDetailSplitSizing.constrainedLeadingPosition(
            proposedLeadingWidth: 640,
            availableWidth: 1100,
            minimumLeadingWidth: 720,
            inspectorWidthRange: 340 ... 420,
            dividerThickness: 1
        )

        XCTAssertEqual(leadingWidth, 720)
    }
}
