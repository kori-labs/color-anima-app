import XCTest
@testable import ColorAnimaAppWorkspaceApplication

final class ProjectSessionCoordinatorReferenceFrameActionsTests: XCTestCase {

    // MARK: - setReferenceFrame

    func testSetReferenceFrameReplacesExistingSet() {
        let cutID = makeID(1)
        let frameA = makeID(10)
        let frameB = makeID(11)
        var state = ProjectReferenceFrameActionsState(
            activeCutID: cutID,
            keyFrameIDsByCutID: [cutID: [frameA]]
        )

        ProjectSessionCoordinator.setReferenceFrame(
            frameB,
            knownFrameIDs: [frameA, frameB],
            in: &state
        )

        XCTAssertEqual(state.keyFrameIDsByCutID[cutID], [frameB])
        XCTAssertTrue(state.isDirty)
        XCTAssertFalse(state.needsRegionRewrite)
        XCTAssertNil(state.regionRewriteTriggerFrameID)
    }

    func testSetReferenceFrameNoOpsWhenFrameUnknown() {
        let cutID = makeID(1)
        let frameA = makeID(10)
        let unknownFrame = makeID(99)
        var state = ProjectReferenceFrameActionsState(
            activeCutID: cutID,
            keyFrameIDsByCutID: [cutID: [frameA]]
        )

        ProjectSessionCoordinator.setReferenceFrame(
            unknownFrame,
            knownFrameIDs: [frameA],
            in: &state
        )

        XCTAssertEqual(state.keyFrameIDsByCutID[cutID], [frameA])
        XCTAssertFalse(state.isDirty)
    }

    func testSetReferenceFrameNoOpsWhenNoActiveCut() {
        let frameA = makeID(10)
        var state = ProjectReferenceFrameActionsState(activeCutID: nil)

        ProjectSessionCoordinator.setReferenceFrame(
            frameA,
            knownFrameIDs: [frameA],
            in: &state
        )

        XCTAssertTrue(state.keyFrameIDsByCutID.isEmpty)
        XCTAssertFalse(state.isDirty)
    }

    // MARK: - addReferenceFrame

    func testAddReferenceFrameAppendsToSet() {
        let cutID = makeID(1)
        let frameA = makeID(10)
        let frameB = makeID(11)
        var state = ProjectReferenceFrameActionsState(
            activeCutID: cutID,
            keyFrameIDsByCutID: [cutID: [frameA]]
        )

        ProjectSessionCoordinator.addReferenceFrame(
            frameB,
            knownFrameIDs: [frameA, frameB],
            cutHasTrackingHistory: false,
            in: &state
        )

        XCTAssertEqual(state.keyFrameIDsByCutID[cutID], [frameA, frameB])
        XCTAssertTrue(state.isDirty)
        XCTAssertFalse(state.needsRegionRewrite)
    }

    func testAddReferenceFrameSetsRegionRewriteWhenCutHasHistory() {
        let cutID = makeID(1)
        let frameA = makeID(10)
        let frameB = makeID(11)
        var state = ProjectReferenceFrameActionsState(
            activeCutID: cutID,
            keyFrameIDsByCutID: [cutID: [frameA]]
        )

        ProjectSessionCoordinator.addReferenceFrame(
            frameB,
            knownFrameIDs: [frameA, frameB],
            cutHasTrackingHistory: true,
            in: &state
        )

        XCTAssertTrue(state.needsRegionRewrite)
        XCTAssertEqual(state.regionRewriteTriggerFrameID, frameB)
    }

    func testAddReferenceFrameDoesNotSetRegionRewriteForDuplicateFrame() {
        let cutID = makeID(1)
        let frameA = makeID(10)
        var state = ProjectReferenceFrameActionsState(
            activeCutID: cutID,
            keyFrameIDsByCutID: [cutID: [frameA]]
        )

        ProjectSessionCoordinator.addReferenceFrame(
            frameA,
            knownFrameIDs: [frameA],
            cutHasTrackingHistory: true,
            in: &state
        )

        XCTAssertFalse(state.needsRegionRewrite)
        XCTAssertNil(state.regionRewriteTriggerFrameID)
    }

    func testAddReferenceFrameNoOpsWhenFrameUnknown() {
        let cutID = makeID(1)
        let unknownFrame = makeID(99)
        var state = ProjectReferenceFrameActionsState(activeCutID: cutID)

        ProjectSessionCoordinator.addReferenceFrame(
            unknownFrame,
            knownFrameIDs: [makeID(10)],
            cutHasTrackingHistory: true,
            in: &state
        )

        XCTAssertTrue(state.keyFrameIDsByCutID[cutID] == nil ||
                      state.keyFrameIDsByCutID[cutID]!.isEmpty)
        XCTAssertFalse(state.isDirty)
        XCTAssertFalse(state.needsRegionRewrite)
    }

    // MARK: - removeReferenceFrame

    func testRemoveReferenceFrameRemovesFromSet() {
        let cutID = makeID(1)
        let frameA = makeID(10)
        let frameB = makeID(11)
        var state = ProjectReferenceFrameActionsState(
            activeCutID: cutID,
            keyFrameIDsByCutID: [cutID: [frameA, frameB]]
        )

        ProjectSessionCoordinator.removeReferenceFrame(frameA, in: &state)

        XCTAssertEqual(state.keyFrameIDsByCutID[cutID], [frameB])
        XCTAssertTrue(state.isDirty)
    }

    func testRemoveReferenceFrameClearsActiveReferenceFrameWhenRemoved() {
        let cutID = makeID(1)
        let frameA = makeID(10)
        let frameB = makeID(11)
        var state = ProjectReferenceFrameActionsState(
            activeCutID: cutID,
            keyFrameIDsByCutID: [cutID: [frameA, frameB]],
            activeReferenceFrameIDByCutID: [cutID: frameA]
        )

        ProjectSessionCoordinator.removeReferenceFrame(frameA, in: &state)

        XCTAssertNil(state.activeReferenceFrameIDByCutID[cutID])
    }

    func testRemoveReferenceFramePreservesActiveReferenceFrameWhenNotRemoved() {
        let cutID = makeID(1)
        let frameA = makeID(10)
        let frameB = makeID(11)
        var state = ProjectReferenceFrameActionsState(
            activeCutID: cutID,
            keyFrameIDsByCutID: [cutID: [frameA, frameB]],
            activeReferenceFrameIDByCutID: [cutID: frameB]
        )

        ProjectSessionCoordinator.removeReferenceFrame(frameA, in: &state)

        XCTAssertEqual(state.activeReferenceFrameIDByCutID[cutID], frameB)
    }

    func testRemoveReferenceFrameNoOpsWhenFrameNotInSet() {
        let cutID = makeID(1)
        let frameA = makeID(10)
        let unknownFrame = makeID(99)
        var state = ProjectReferenceFrameActionsState(
            activeCutID: cutID,
            keyFrameIDsByCutID: [cutID: [frameA]]
        )

        ProjectSessionCoordinator.removeReferenceFrame(unknownFrame, in: &state)

        XCTAssertEqual(state.keyFrameIDsByCutID[cutID], [frameA])
        XCTAssertFalse(state.isDirty)
    }

    // MARK: - setActiveReferenceFrame

    func testSetActiveReferenceFrameUpdatesActiveID() {
        let cutID = makeID(1)
        let frameA = makeID(10)
        let frameB = makeID(11)
        var state = ProjectReferenceFrameActionsState(
            activeCutID: cutID,
            keyFrameIDsByCutID: [cutID: [frameA, frameB]],
            activeReferenceFrameIDByCutID: [cutID: frameA]
        )

        ProjectSessionCoordinator.setActiveReferenceFrame(frameB, in: &state)

        XCTAssertEqual(state.activeReferenceFrameIDByCutID[cutID], frameB)
        XCTAssertTrue(state.isDirty)
    }

    func testSetActiveReferenceFrameNoOpsWhenFrameNotInReferenceSet() {
        let cutID = makeID(1)
        let frameA = makeID(10)
        let unknownFrame = makeID(99)
        var state = ProjectReferenceFrameActionsState(
            activeCutID: cutID,
            keyFrameIDsByCutID: [cutID: [frameA]],
            activeReferenceFrameIDByCutID: [cutID: frameA]
        )

        ProjectSessionCoordinator.setActiveReferenceFrame(unknownFrame, in: &state)

        XCTAssertEqual(state.activeReferenceFrameIDByCutID[cutID], frameA)
        XCTAssertFalse(state.isDirty)
    }

    // MARK: - clearRegionRewriteRequest

    func testClearRegionRewriteRequestClearsFlags() {
        let cutID = makeID(1)
        let frameA = makeID(10)
        var state = ProjectReferenceFrameActionsState(
            activeCutID: cutID,
            needsRegionRewrite: true,
            regionRewriteTriggerFrameID: frameA
        )

        ProjectSessionCoordinator.clearRegionRewriteRequest(in: &state)

        XCTAssertFalse(state.needsRegionRewrite)
        XCTAssertNil(state.regionRewriteTriggerFrameID)
    }

    // MARK: - Read helpers

    func testReferenceFrameIDsReturnsSetForActiveCut() {
        let cutID = makeID(1)
        let frameA = makeID(10)
        let frameB = makeID(11)
        let state = ProjectReferenceFrameActionsState(
            activeCutID: cutID,
            keyFrameIDsByCutID: [cutID: [frameA, frameB]]
        )

        let result = ProjectSessionCoordinator.keyFrameIDs(in: state)

        XCTAssertEqual(result, [frameA, frameB])
    }

    func testReferenceFrameIDsReturnsEmptyWhenNoActiveCut() {
        let state = ProjectReferenceFrameActionsState(activeCutID: nil)

        let result = ProjectSessionCoordinator.keyFrameIDs(in: state)

        XCTAssertTrue(result.isEmpty)
    }

    func testActiveReferenceFrameIDReturnsValueForActiveCut() {
        let cutID = makeID(1)
        let frameA = makeID(10)
        let state = ProjectReferenceFrameActionsState(
            activeCutID: cutID,
            keyFrameIDsByCutID: [cutID: [frameA]],
            activeReferenceFrameIDByCutID: [cutID: frameA]
        )

        let result = ProjectSessionCoordinator.activeReferenceFrameID(in: state)

        XCTAssertEqual(result, frameA)
    }

    func testActiveReferenceFrameIDReturnsNilWhenNoActiveCut() {
        let state = ProjectReferenceFrameActionsState(activeCutID: nil)

        let result = ProjectSessionCoordinator.activeReferenceFrameID(in: state)

        XCTAssertNil(result)
    }

    // MARK: - Helpers

    private func makeID(_ value: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", value))!
    }
}
