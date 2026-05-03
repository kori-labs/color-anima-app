import XCTest
@testable import ColorAnimaAppWorkspaceApplication

final class CutWorkspaceFrameWorkflowCoordinatorTests: XCTestCase {
    func testCreateFrameAppendsDefaultNamedFrameAndSelectsIt() {
        let ids = makeFrameIDs(count: 2)
        let newFrameID = makeFrameID(3)
        var state = makeState(ids)

        let frame = CutWorkspaceFrameWorkflowCoordinator.createFrame(id: newFrameID, in: &state)

        XCTAssertEqual(frame.id, newFrameID)
        XCTAssertEqual(frame.orderIndex, 2)
        XCTAssertEqual(frame.name, "Frame 003")
        XCTAssertEqual(state.orderedFrameIDs, [ids[0], ids[1], newFrameID])
        XCTAssertEqual(state.selectedFrameID, newFrameID)
        XCTAssertEqual(state.selectedFrameIDs, [newFrameID])
        XCTAssertEqual(state.selectedFrameSelectionAnchorID, newFrameID)
        XCTAssertEqual(state.lastOpenedFrameID, newFrameID)
        XCTAssertEqual(state.framePresentationSeedFrameID, newFrameID)
        XCTAssertEqual(state.framePresentationRestoreFrameID, newFrameID)
        XCTAssertTrue(state.needsFramePresentationPreparation)
        XCTAssertTrue(state.isDirty)
        XCTAssertEqual(state.documentRevision, 1)
    }

    func testMoveFramesReordersAndRenamesDefaultNamedFrames() {
        let ids = makeFrameIDs(count: 4)
        var state = CutWorkspaceFrameWorkflowState(
            frames: [
                makeFrame(ids[0], orderIndex: 0, name: "Frame 001"),
                makeFrame(ids[1], orderIndex: 1, name: "Frame 002"),
                makeFrame(ids[2], orderIndex: 2, name: "Custom"),
                makeFrame(ids[3], orderIndex: 3, name: "Frame 004"),
            ],
            selectedFrameID: ids[0],
            selectedFrameIDs: [ids[0]],
            selectedFrameSelectionAnchorID: ids[0],
            lastOpenedFrameID: ids[0],
            keyFrameIDs: [ids[1], ids[3]],
            activeReferenceFrameID: ids[3]
        )

        let moved = CutWorkspaceFrameWorkflowCoordinator.moveFrames(
            [ids[3], ids[1], ids[1]],
            to: WorkspaceFrameDropTarget(targetFrameID: ids[0], position: .before),
            in: &state
        )

        XCTAssertEqual(moved, [ids[1], ids[3]])
        XCTAssertEqual(state.orderedFrameIDs, [ids[1], ids[3], ids[0], ids[2]])
        XCTAssertEqual(state.orderedFrames.map(\.orderIndex), [0, 1, 2, 3])
        XCTAssertEqual(state.orderedFrames.map(\.name), ["Frame 001", "Frame 002", "Frame 003", "Custom"])
        XCTAssertEqual(state.selectedFrameID, ids[1])
        XCTAssertEqual(state.selectedFrameIDs, [ids[1], ids[3]])
        XCTAssertEqual(state.selectedFrameSelectionAnchorID, ids[1])
        XCTAssertEqual(state.lastOpenedFrameID, ids[1])
        XCTAssertEqual(state.keyFrameIDs, [ids[1], ids[3]])
        XCTAssertEqual(state.activeReferenceFrameID, ids[3])
        XCTAssertEqual(state.framePresentationRestoreFrameID, ids[1])
        XCTAssertTrue(state.isDirty)
        XCTAssertEqual(state.documentRevision, 1)
    }

    func testMoveRejectsDroppingOntoMovedFrame() {
        let ids = makeFrameIDs(count: 3)
        var state = makeState(ids)
        let snapshot = state

        let moved = CutWorkspaceFrameWorkflowCoordinator.moveFrames(
            [ids[1]],
            to: WorkspaceFrameDropTarget(targetFrameID: ids[1], position: .after),
            in: &state
        )

        XCTAssertNil(moved)
        XCTAssertEqual(state.frames, snapshot.frames)
        XCTAssertEqual(state.documentRevision, snapshot.documentRevision)
    }

    func testDeleteFramesSelectsNeighborRemovesCachesAndStopsPlayback() {
        let ids = makeFrameIDs(count: 4)
        var state = CutWorkspaceFrameWorkflowState(
            frames: ids.enumerated().map { makeFrame($0.element, orderIndex: $0.offset) },
            selectedFrameID: ids[1],
            selectedFrameIDs: [ids[1], ids[2]],
            selectedFrameSelectionAnchorID: ids[1],
            lastOpenedFrameID: ids[1],
            keyFrameIDs: [ids[1], ids[2], ids[3]],
            activeReferenceFrameID: ids[2],
            isFramePlaybackActive: true
        )

        let primaryFrameID = CutWorkspaceFrameWorkflowCoordinator.deleteFrames([ids[1], ids[2]], in: &state)

        XCTAssertEqual(primaryFrameID, ids[3])
        XCTAssertEqual(state.orderedFrameIDs, [ids[0], ids[3]])
        XCTAssertEqual(state.orderedFrames.map(\.name), ["Frame 001", "Frame 002"])
        XCTAssertEqual(state.selectedFrameID, ids[3])
        XCTAssertEqual(state.selectedFrameIDs, [ids[3]])
        XCTAssertEqual(state.selectedFrameSelectionAnchorID, ids[3])
        XCTAssertEqual(state.lastOpenedFrameID, ids[3])
        XCTAssertFalse(state.isFramePlaybackActive)
        XCTAssertEqual(state.removedFrameIDs, [ids[1], ids[2]])
        XCTAssertEqual(state.keyFrameIDs, [ids[3]])
        XCTAssertEqual(state.activeReferenceFrameID, ids[3])
        XCTAssertEqual(state.framePresentationRestoreFrameID, ids[3])
        XCTAssertTrue(state.isDirty)
        XCTAssertEqual(state.documentRevision, 1)
    }

    func testDeleteRejectsDeletingAllFrames() {
        let ids = makeFrameIDs(count: 2)
        var state = makeState(ids)
        let snapshot = state

        let primaryFrameID = CutWorkspaceFrameWorkflowCoordinator.deleteFrames(ids, in: &state)

        XCTAssertNil(primaryFrameID)
        XCTAssertEqual(state.frames, snapshot.frames)
        XCTAssertEqual(state.documentRevision, snapshot.documentRevision)
    }

    func testReferenceFrameActionsMaintainOrderedValidReferences() {
        let ids = makeFrameIDs(count: 4)
        var state = makeState(ids)

        XCTAssertTrue(CutWorkspaceFrameWorkflowCoordinator.addReferenceFrame(ids[2], in: &state))
        XCTAssertTrue(CutWorkspaceFrameWorkflowCoordinator.addReferenceFrame(ids[0], in: &state))
        XCTAssertTrue(CutWorkspaceFrameWorkflowCoordinator.addReferenceFrame(ids[1], in: &state))
        XCTAssertFalse(CutWorkspaceFrameWorkflowCoordinator.addReferenceFrame(ids[3], in: &state))
        XCTAssertEqual(state.keyFrameIDs, [ids[0], ids[1], ids[2]])
        XCTAssertEqual(state.activeReferenceFrameID, ids[2])

        CutWorkspaceFrameWorkflowCoordinator.removeReferenceFrame(ids[2], in: &state)

        XCTAssertEqual(state.keyFrameIDs, [ids[0], ids[1]])
        XCTAssertEqual(state.activeReferenceFrameID, ids[0])

        CutWorkspaceFrameWorkflowCoordinator.setReferenceFrame(nil, in: &state)

        XCTAssertEqual(state.keyFrameIDs, [])
        XCTAssertNil(state.activeReferenceFrameID)
        XCTAssertTrue(state.isDirty)
    }

    func testNormalizeFrameStateCreatesFallbackFrameAndNormalizesLastOpened() {
        let state = CutWorkspaceFrameWorkflowState(
            frames: [],
            lastOpenedFrameID: UUID(),
            keyFrameIDs: [UUID()],
            activeReferenceFrameID: UUID()
        )

        XCTAssertEqual(state.frames.count, 1)
        XCTAssertEqual(state.orderedFrames[0].orderIndex, 0)
        XCTAssertEqual(state.orderedFrames[0].name, "Frame 001")
        XCTAssertEqual(state.lastOpenedFrameID, state.orderedFrames[0].id)
        XCTAssertEqual(state.keyFrameIDs, [])
        XCTAssertNil(state.activeReferenceFrameID)
    }

    private func makeState(_ frameIDs: [UUID]) -> CutWorkspaceFrameWorkflowState {
        let primary = frameIDs.first
        return CutWorkspaceFrameWorkflowState(
            frames: frameIDs.enumerated().map { makeFrame($0.element, orderIndex: $0.offset) },
            selectedFrameID: primary,
            selectedFrameIDs: Set([primary].compactMap { $0 }),
            selectedFrameSelectionAnchorID: primary,
            lastOpenedFrameID: primary
        )
    }

    private func makeFrame(
        _ id: UUID,
        orderIndex: Int,
        name: String? = nil
    ) -> CutWorkspaceFrameWorkflowFrame {
        CutWorkspaceFrameWorkflowFrame(
            id: id,
            orderIndex: orderIndex,
            name: name ?? CutWorkspaceFrameWorkflowCoordinator.defaultFrameName(for: orderIndex + 1)
        )
    }

    private func makeFrameIDs(count: Int) -> [UUID] {
        (0..<count).map { makeFrameID($0 + 1) }
    }

    private func makeFrameID(_ index: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index))!
    }
}
