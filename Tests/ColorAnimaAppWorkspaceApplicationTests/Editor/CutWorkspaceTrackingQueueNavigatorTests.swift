import XCTest
@testable import ColorAnimaAppWorkspaceApplication

final class CutWorkspaceTrackingQueueNavigatorTests: XCTestCase {
    func testPresentationMapsCurrentQueueItemAndNavigationState() throws {
        let firstFrameID = UUID()
        let secondFrameID = UUID()
        let firstRegionID = UUID()
        let secondRegionID = UUID()
        let frames = [
            CutWorkspaceTrackingQueueFrame(
                id: firstFrameID,
                orderIndex: 0,
                regions: [
                    CutWorkspaceTrackingQueueRegion(
                        id: firstRegionID,
                        displayName: "   ",
                        confidenceValue: 0.62
                    )
                ]
            ),
            CutWorkspaceTrackingQueueFrame(
                id: secondFrameID,
                orderIndex: 1,
                regions: [
                    CutWorkspaceTrackingQueueRegion(
                        id: secondRegionID,
                        displayName: "Face",
                        confidenceValue: 0.84
                    )
                ]
            ),
        ]
        let state = CutWorkspaceTrackingQueueState(
            queueItems: [
                CutWorkspaceTrackingQueueItemState(
                    frameID: firstFrameID,
                    regionID: firstRegionID,
                    reviewState: .reviewNeeded,
                    reasonCodes: [.lowMargin]
                ),
                CutWorkspaceTrackingQueueItemState(
                    frameID: secondFrameID,
                    regionID: secondRegionID,
                    reviewState: .unresolved,
                    reasonCodes: [.structuralConflict],
                    hasResolvedAssignment: true
                ),
            ],
            queueIndex: 1
        )

        let presentation = try XCTUnwrap(
            CutWorkspaceTrackingQueueNavigator.makeQueueNavigatorPresentation(
                state: state,
                frames: frames,
                selectedSubsetID: UUID()
            )
        )

        XCTAssertEqual(presentation.frameID, secondFrameID)
        XCTAssertEqual(presentation.regionID, secondRegionID)
        XCTAssertEqual(presentation.currentIndex, 1)
        XCTAssertEqual(presentation.totalCount, 2)
        XCTAssertEqual(presentation.severity, .unresolved)
        XCTAssertTrue(presentation.canGoBackward)
        XCTAssertFalse(presentation.canGoForward)
        XCTAssertTrue(presentation.canAccept)
        XCTAssertTrue(presentation.canReassign)
        XCTAssertFalse(presentation.canSkip)
        XCTAssertEqual(presentation.currentItem?.regionDisplayName, "Face")
        XCTAssertEqual(presentation.currentItem?.confidenceValue, 0.84)
        XCTAssertEqual(presentation.items.first?.regionDisplayName, String(firstRegionID.uuidString.prefix(8)))
        XCTAssertEqual(presentation.items.map(\.reasonCodes), [[.lowMargin], [.structuralConflict]])
    }

    func testPresentationReturnsNilWhenCurrentItemCannotResolveFrameOrRegion() {
        let frameID = UUID()
        let missingRegionID = UUID()
        let state = CutWorkspaceTrackingQueueState(
            queueItems: [
                CutWorkspaceTrackingQueueItemState(
                    frameID: frameID,
                    regionID: missingRegionID,
                    reviewState: .reviewNeeded
                )
            ]
        )

        XCTAssertNil(
            CutWorkspaceTrackingQueueNavigator.makeQueueNavigatorPresentation(
                state: state,
                frames: [
                    CutWorkspaceTrackingQueueFrame(id: frameID, orderIndex: 0, regions: [])
                ],
                selectedSubsetID: nil
            )
        )
    }

    func testManualOverrideDisablesAcceptAndReassign() throws {
        let frameID = UUID()
        let regionID = UUID()
        let state = CutWorkspaceTrackingQueueState(
            queueItems: [
                CutWorkspaceTrackingQueueItemState(
                    frameID: frameID,
                    regionID: regionID,
                    reviewState: .reviewNeeded,
                    hasResolvedAssignment: true
                )
            ]
        )
        let frames = [
            CutWorkspaceTrackingQueueFrame(
                id: frameID,
                orderIndex: 0,
                regions: [
                    CutWorkspaceTrackingQueueRegion(
                        id: regionID,
                        displayName: "Hair",
                        isManualOverride: true
                    )
                ]
            )
        ]

        let presentation = try XCTUnwrap(
            CutWorkspaceTrackingQueueNavigator.makeQueueNavigatorPresentation(
                state: state,
                frames: frames,
                selectedSubsetID: UUID()
            )
        )

        XCTAssertFalse(presentation.canAccept)
        XCTAssertFalse(presentation.canReassign)
        XCTAssertTrue(presentation.currentItem?.isManualOverride == true)
    }

    func testCursorMovementClampsToQueueBounds() {
        var state: CutWorkspaceTrackingQueueState? = CutWorkspaceTrackingQueueState(
            queueItems: [
                makeItem(),
                makeItem(),
                makeItem(),
            ],
            queueIndex: 1
        )

        CutWorkspaceTrackingQueueNavigator.moveQueueCursor(in: &state, delta: 10)
        XCTAssertEqual(state?.queueIndex, 2)

        CutWorkspaceTrackingQueueNavigator.moveQueueCursor(in: &state, delta: -10)
        XCTAssertEqual(state?.queueIndex, 0)

        CutWorkspaceTrackingQueueNavigator.setQueueCursor(in: &state, to: 1)
        XCTAssertEqual(state?.queueIndex, 1)

        CutWorkspaceTrackingQueueNavigator.setQueueCursor(in: &state, to: -3)
        XCTAssertEqual(state?.queueIndex, 0)
    }

    func testCursorMovementIgnoresNilOrEmptyState() {
        var nilState: CutWorkspaceTrackingQueueState?
        CutWorkspaceTrackingQueueNavigator.moveQueueCursor(in: &nilState, delta: 1)
        XCTAssertNil(nilState)

        var emptyState: CutWorkspaceTrackingQueueState? = CutWorkspaceTrackingQueueState(queueItems: [])
        CutWorkspaceTrackingQueueNavigator.setQueueCursor(in: &emptyState, to: 2)
        XCTAssertEqual(emptyState?.queueIndex, 0)
    }

    private func makeItem() -> CutWorkspaceTrackingQueueItemState {
        CutWorkspaceTrackingQueueItemState(
            frameID: UUID(),
            regionID: UUID(),
            reviewState: .reviewNeeded
        )
    }
}
