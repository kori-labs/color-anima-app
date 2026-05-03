import XCTest
@testable import ColorAnimaAppWorkspaceApplication

final class CutWorkspaceAssignmentSyncCoordinatorTests: XCTestCase {
    func testRewriteAcrossCutUpdatesMatchingAssignmentsAndTrackingRecords() {
        let fixture = makeFixture()
        var cutState = fixture.cutState

        let result = CutWorkspaceAssignmentSyncCoordinator.rewriteStatusAcrossCut(
            inSubsetID: fixture.targetSubsetID,
            from: "default",
            to: "renamed",
            in: &cutState
        )

        XCTAssertEqual(Set(result.updatedFrameIDs), Set([fixture.referenceFrameID, fixture.trackedFrameID]))
        XCTAssertTrue(result.didRewriteAnything)

        let referenceFrame = cutState.frames.first { $0.id == fixture.referenceFrameID }
        let trackedFrame = cutState.frames.first { $0.id == fixture.trackedFrameID }
        let referenceRegionA = referenceFrame?.regions.first { $0.id == fixture.regionAID }
        let referenceRegionB = referenceFrame?.regions.first { $0.id == fixture.regionBID }
        let trackedRegionA = trackedFrame?.regions.first { $0.id == fixture.regionAID }
        let trackedRegionB = trackedFrame?.regions.first { $0.id == fixture.regionBID }

        XCTAssertEqual(referenceRegionA?.assignment?.statusName, "renamed")
        XCTAssertEqual(referenceRegionA?.assignment?.subsetID, fixture.targetSubsetID)
        XCTAssertEqual(referenceRegionB?.assignment?.statusName, "default")
        XCTAssertEqual(referenceRegionB?.assignment?.subsetID, fixture.otherSubsetID)
        XCTAssertEqual(trackedRegionA?.assignment?.statusName, "renamed")
        XCTAssertEqual(trackedRegionB?.assignment?.statusName, "default")

        let propagatedA = trackedFrame?.trackingRecords
            .first { $0.targetRegionID == fixture.regionAID }?
            .assignedRegion
        let propagatedB = trackedFrame?.trackingRecords
            .first { $0.targetRegionID == fixture.regionBID }?
            .assignedRegion
        XCTAssertEqual(propagatedA?.statusName, "renamed")
        XCTAssertEqual(propagatedA?.subsetID, fixture.targetSubsetID)
        XCTAssertEqual(propagatedB?.statusName, "default")
        XCTAssertEqual(propagatedB?.subsetID, fixture.otherSubsetID)
    }

    func testManualCorrectionMetadataAndSplitDecisionsArePreserved() {
        let fixture = makeFixture()
        var cutState = fixture.cutState
        let trackedFrameIndex = cutState.frames.firstIndex { $0.id == fixture.trackedFrameID }!
        let targetRecordIndex = cutState.frames[trackedFrameIndex].trackingRecords
            .firstIndex { $0.targetRegionID == fixture.regionAID }!

        cutState.frames[trackedFrameIndex].trackingRecords[targetRecordIndex].isManualCorrection = true
        cutState.frames[trackedFrameIndex].trackingRecords[targetRecordIndex].reviewState = .tracked
        cutState.frames[trackedFrameIndex].trackingRecords[targetRecordIndex].assignedRegion =
            AssignmentSyncAssignment(
                groupID: fixture.groupID,
                subsetID: fixture.targetSubsetID,
                statusName: "default",
                highlightSplitDecision: .inverted,
                shadowSplitDecision: .inverted
            )
        let targetRegionIndex = cutState.frames[trackedFrameIndex].regions
            .firstIndex { $0.id == fixture.regionAID }!
        cutState.frames[trackedFrameIndex].regions[targetRegionIndex].assignment =
            AssignmentSyncAssignment(
                groupID: fixture.groupID,
                subsetID: fixture.targetSubsetID,
                statusName: "default",
                highlightSplitDecision: .inverted,
                shadowSplitDecision: .inverted
            )

        let result = CutWorkspaceAssignmentSyncCoordinator.rewriteStatusAcrossCut(
            inSubsetID: fixture.targetSubsetID,
            from: "default",
            to: "renamed",
            in: &cutState
        )

        XCTAssertTrue(result.updatedFrameIDs.contains(fixture.trackedFrameID))
        let updatedFrame = cutState.frames.first { $0.id == fixture.trackedFrameID }
        let updatedAssignment = updatedFrame?.regions
            .first { $0.id == fixture.regionAID }?
            .assignment
        XCTAssertEqual(updatedAssignment?.statusName, "renamed")
        XCTAssertEqual(updatedAssignment?.highlightSplitDecision, .inverted)
        XCTAssertEqual(updatedAssignment?.shadowSplitDecision, .inverted)

        let updatedRecord = updatedFrame?.trackingRecords.first { $0.targetRegionID == fixture.regionAID }
        XCTAssertEqual(updatedRecord?.isManualCorrection, true)
        XCTAssertEqual(updatedRecord?.reviewState, .tracked)
        XCTAssertEqual(updatedRecord?.assignedRegion?.statusName, "renamed")
        XCTAssertEqual(updatedRecord?.assignedRegion?.highlightSplitDecision, .inverted)
        XCTAssertEqual(updatedRecord?.assignedRegion?.shadowSplitDecision, .inverted)
    }

    func testRewriteSyncsPublicPrototypeState() {
        let fixture = makeFixture()
        var cutState = fixture.cutState
        cutState.prototypes = [
            AssignmentSyncPrototype(
                subsetID: fixture.targetSubsetID,
                referenceMembers: [
                    AssignmentSyncPrototypeMember(
                        frameID: fixture.referenceFrameID,
                        regionID: fixture.regionAID,
                        assignment: AssignmentSyncAssignment(
                            groupID: fixture.groupID,
                            subsetID: fixture.targetSubsetID,
                            statusName: "default"
                        )
                    )
                ],
                canonicalAssignment: AssignmentSyncAssignment(
                    groupID: fixture.groupID,
                    subsetID: fixture.targetSubsetID,
                    statusName: "default"
                )
            ),
            AssignmentSyncPrototype(
                subsetID: fixture.otherSubsetID,
                referenceMembers: [
                    AssignmentSyncPrototypeMember(
                        frameID: fixture.referenceFrameID,
                        regionID: fixture.regionBID,
                        assignment: AssignmentSyncAssignment(
                            groupID: fixture.groupID,
                            subsetID: fixture.otherSubsetID,
                            statusName: "default"
                        )
                    )
                ]
            ),
        ]

        let result = CutWorkspaceAssignmentSyncCoordinator.rewriteStatusAcrossCut(
            inSubsetID: fixture.targetSubsetID,
            from: "default",
            to: "renamed",
            in: &cutState
        )

        XCTAssertTrue(result.didRewritePrototypes)

        let targetPrototype = cutState.prototypes.first { $0.subsetID == fixture.targetSubsetID }
        XCTAssertEqual(targetPrototype?.canonicalStatusName, "renamed")
        XCTAssertEqual(targetPrototype?.referenceMembers.map(\.assignment.statusName), ["renamed"])

        let otherPrototype = cutState.prototypes.first { $0.subsetID == fixture.otherSubsetID }
        XCTAssertEqual(otherPrototype?.canonicalStatusName, "default")
        XCTAssertEqual(otherPrototype?.referenceMembers.map(\.assignment.statusName), ["default"])
    }

    func testNoOpWhenStatusNameDoesNotChange() {
        let fixture = makeFixture()
        var cutState = fixture.cutState

        let result = CutWorkspaceAssignmentSyncCoordinator.rewriteStatusAcrossCut(
            inSubsetID: fixture.targetSubsetID,
            from: "default",
            to: "default",
            in: &cutState
        )

        XCTAssertFalse(result.didRewriteAnything)
        XCTAssertEqual(cutState, fixture.cutState)
    }

    private func makeFixture() -> Fixture {
        let referenceFrameID = UUID(uuidString: "00000000-0000-0000-0000-0000000E0001")!
        let trackedFrameID = UUID(uuidString: "00000000-0000-0000-0000-0000000E0002")!
        let regionAID = UUID(uuidString: "00000000-0000-0000-0000-0000000E0010")!
        let regionBID = UUID(uuidString: "00000000-0000-0000-0000-0000000E0011")!
        let groupID = UUID(uuidString: "00000000-0000-0000-0000-0000000E0020")!
        let targetSubsetID = UUID(uuidString: "00000000-0000-0000-0000-0000000E0021")!
        let otherSubsetID = UUID(uuidString: "00000000-0000-0000-0000-0000000E0022")!

        let referenceFrame = AssignmentSyncFrameState(
            id: referenceFrameID,
            regions: [
                makeRegion(id: regionAID, groupID: groupID, subsetID: targetSubsetID),
                makeRegion(id: regionBID, groupID: groupID, subsetID: otherSubsetID),
            ]
        )
        let trackedFrame = AssignmentSyncFrameState(
            id: trackedFrameID,
            regions: [
                makeRegion(id: regionAID, groupID: groupID, subsetID: targetSubsetID),
                makeRegion(id: regionBID, groupID: groupID, subsetID: otherSubsetID),
            ],
            trackingRecords: [
                makeTrackingRecord(regionID: regionAID, groupID: groupID, subsetID: targetSubsetID),
                makeTrackingRecord(regionID: regionBID, groupID: groupID, subsetID: otherSubsetID),
            ]
        )

        return Fixture(
            cutState: AssignmentSyncCutState(frames: [referenceFrame, trackedFrame]),
            referenceFrameID: referenceFrameID,
            trackedFrameID: trackedFrameID,
            groupID: groupID,
            targetSubsetID: targetSubsetID,
            otherSubsetID: otherSubsetID,
            regionAID: regionAID,
            regionBID: regionBID
        )
    }

    private func makeRegion(
        id: UUID,
        groupID: UUID,
        subsetID: UUID
    ) -> AssignmentSyncRegionState {
        AssignmentSyncRegionState(
            id: id,
            assignment: AssignmentSyncAssignment(
                groupID: groupID,
                subsetID: subsetID,
                statusName: "default"
            )
        )
    }

    private func makeTrackingRecord(
        regionID: UUID,
        groupID: UUID,
        subsetID: UUID
    ) -> AssignmentSyncTrackingRecord {
        AssignmentSyncTrackingRecord(
            targetRegionID: regionID,
            reviewState: .tracked,
            assignedRegion: AssignmentSyncAssignment(
                groupID: groupID,
                subsetID: subsetID,
                statusName: "default"
            )
        )
    }

    private struct Fixture {
        let cutState: AssignmentSyncCutState
        let referenceFrameID: UUID
        let trackedFrameID: UUID
        let groupID: UUID
        let targetSubsetID: UUID
        let otherSubsetID: UUID
        let regionAID: UUID
        let regionBID: UUID
    }
}
