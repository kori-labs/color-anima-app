import XCTest
@testable import ColorAnimaAppWorkspaceApplication

final class CutWorkspaceTrackingSessionRestorerTests: XCTestCase {
    func testRestoreReturnsExistingSessionStateWhenPresent() {
        let existing = CutWorkspaceTrackingSessionState(runStatus: .running(message: "Tracking", current: 1, total: 2))
        let frame = PersistedTrackingFrameState(records: [
            PersistedTrackingRecordState(regionID: UUID(), reviewState: .reviewNeeded)
        ])

        let restored = CutWorkspaceTrackingSessionRestorer.restoreSessionStateFromPersistedTracking(
            existingSessionState: existing,
            frames: [frame]
        )

        XCTAssertEqual(restored, existing)
    }

    func testRestoreReturnsNilWhenNoPersistedTrackingExists() {
        let restored = CutWorkspaceTrackingSessionRestorer.restoreSessionStateFromPersistedTracking(
            existingSessionState: nil,
            frames: [
                PersistedTrackingFrameState(records: []),
                PersistedTrackingFrameState(records: []),
            ]
        )

        XCTAssertNil(restored)
    }

    func testRestoreBuildsQueueFromReviewNeededAndUnresolvedRecords() throws {
        let firstFrameID = UUID()
        let secondFrameID = UUID()
        let trackedRegionID = UUID()
        let reviewRegionID = UUID()
        let unresolvedRegionID = UUID()

        let restored = try XCTUnwrap(
            CutWorkspaceTrackingSessionRestorer.restoreSessionStateFromPersistedTracking(
                existingSessionState: nil,
                frames: [
                    PersistedTrackingFrameState(
                        id: secondFrameID,
                        orderIndex: 1,
                        records: [
                            PersistedTrackingRecordState(
                                regionID: unresolvedRegionID,
                                reviewState: .unresolved,
                                reasonCodes: [.lowMargin],
                                hasResolvedAssignment: false
                            )
                        ]
                    ),
                    PersistedTrackingFrameState(
                        id: firstFrameID,
                        orderIndex: 0,
                        records: [
                            PersistedTrackingRecordState(
                                regionID: trackedRegionID,
                                reviewState: .tracked,
                                hasResolvedAssignment: true
                            ),
                            PersistedTrackingRecordState(
                                regionID: reviewRegionID,
                                reviewState: .reviewNeeded,
                                reasonCodes: [.split, .merge],
                                hasResolvedAssignment: true
                            ),
                        ]
                    ),
                ]
            )
        )

        XCTAssertEqual(restored.runStatus, .completed)
        XCTAssertEqual(restored.lastRunResult?.reviewItemCount, 2)
        XCTAssertEqual(restored.regionQueueItems.map(\.frameID), [firstFrameID, secondFrameID])
        XCTAssertEqual(restored.regionQueueItems.map(\.regionID), [reviewRegionID, unresolvedRegionID])
        XCTAssertEqual(restored.regionQueueItems.first?.reasonCodes, [.split, .merge])
        XCTAssertEqual(restored.regionQueueItems.first?.hasResolvedAssignment, true)
        XCTAssertEqual(restored.regionQueueItems.last?.reviewState, .unresolved)
    }

    func testManualUnresolvedRecordsAreNotRestoredToReviewQueue() throws {
        let frameID = UUID()
        let manualUnresolvedID = UUID()
        let manualReviewID = UUID()

        let restored = try XCTUnwrap(
            CutWorkspaceTrackingSessionRestorer.restoreSessionStateFromPersistedTracking(
                existingSessionState: nil,
                frames: [
                    PersistedTrackingFrameState(
                        id: frameID,
                        orderIndex: 0,
                        records: [
                            PersistedTrackingRecordState(
                                regionID: manualUnresolvedID,
                                reviewState: .unresolved,
                                isManualCorrection: true
                            ),
                            PersistedTrackingRecordState(
                                regionID: manualReviewID,
                                reviewState: .reviewNeeded,
                                isManualCorrection: true
                            ),
                        ]
                    )
                ]
            )
        )

        XCTAssertEqual(restored.regionQueueItems.map(\.regionID), [manualReviewID])
    }

    func testAnchorIDSetsAreNormalizedByRestoredSessionState() throws {
        let high = UUID(uuidString: "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF")!
        let low = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
        let frame = PersistedTrackingFrameState(records: [
            PersistedTrackingRecordState(regionID: UUID(), reviewState: .reviewNeeded)
        ])

        let restored = try XCTUnwrap(
            CutWorkspaceTrackingSessionRestorer.restoreSessionStateFromPersistedTracking(
                existingSessionState: nil,
                frames: [frame],
                promotedAnchorFrameIDs: [high, low, high],
                excludedAnchorFrameIDs: [high, low, low]
            )
        )

        XCTAssertEqual(restored.promotedAnchorFrameIDs, [low, high])
        XCTAssertEqual(restored.excludedAnchorFrameIDs, [low, high])
    }

    func testHasTrackingContextReflectsPersistedRecords() {
        let frameID = UUID()
        let regionID = UUID()
        let frames = [
            PersistedTrackingFrameState(
                id: frameID,
                orderIndex: 0,
                records: [
                    PersistedTrackingRecordState(regionID: regionID, reviewState: .tracked)
                ]
            )
        ]

        XCTAssertTrue(
            CutWorkspaceTrackingSessionRestorer.hasTrackingContext(
                frameID: frameID,
                regionID: regionID,
                in: frames
            )
        )
        XCTAssertFalse(
            CutWorkspaceTrackingSessionRestorer.hasTrackingContext(
                frameID: frameID,
                regionID: UUID(),
                in: frames
            )
        )
    }
}
