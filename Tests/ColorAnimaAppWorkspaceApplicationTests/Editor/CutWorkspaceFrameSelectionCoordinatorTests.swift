import XCTest
@testable import ColorAnimaAppWorkspaceApplication

final class CutWorkspaceFrameSelectionCoordinatorTests: XCTestCase {
    func testPlainSelectionCollapsesToSinglePrimaryFrame() {
        let ids = makeFrameIDs(count: 4)
        var state = makeState(ids)

        let outcome = CutWorkspaceFrameSelectionCoordinator.selectFrame(ids[2], in: &state)

        XCTAssertEqual(outcome, .changed(primaryFrameID: ids[2], previousPrimaryFrameID: ids[0]))
        XCTAssertEqual(state.selectedFrameID, ids[2])
        XCTAssertEqual(state.selectedFrameIDs, [ids[2]])
        XCTAssertEqual(state.selectedFrameSelectionAnchorID, ids[2])
        XCTAssertEqual(state.lastOpenedFrameID, ids[2])
    }

    func testSelectingSamePrimaryUpdatesSelectionButReportsUnchangedPresentation() {
        let ids = makeFrameIDs(count: 3)
        var state = makeState(
            ids,
            selectedFrameID: ids[1],
            selectedFrameIDs: [ids[0], ids[1]],
            anchorID: ids[0],
            lastOpenedFrameID: ids[1]
        )

        let outcome = CutWorkspaceFrameSelectionCoordinator.selectFrame(ids[1], in: &state)

        XCTAssertEqual(outcome, .unchanged)
        XCTAssertEqual(state.selectedFrameIDs, [ids[1]])
        XCTAssertEqual(state.selectedFrameSelectionAnchorID, ids[1])
    }

    func testAdditiveSelectionAddsAndRemovesFrames() {
        let ids = makeFrameIDs(count: 4)
        var state = makeState(ids, selectedFrameID: ids[1], selectedFrameIDs: [ids[1]], anchorID: ids[1])

        let addOutcome = CutWorkspaceFrameSelectionCoordinator.selectFrame(
            ids[3],
            modifiers: .additive,
            in: &state
        )

        XCTAssertEqual(addOutcome, .changed(primaryFrameID: ids[3], previousPrimaryFrameID: ids[1]))
        XCTAssertEqual(state.selectedFrameIDs, [ids[1], ids[3]])
        XCTAssertEqual(state.selectedFrameSelectionAnchorID, ids[3])

        let removeOutcome = CutWorkspaceFrameSelectionCoordinator.selectFrame(
            ids[1],
            modifiers: .additive,
            in: &state
        )

        XCTAssertEqual(removeOutcome, .unchanged)
        XCTAssertEqual(state.selectedFrameID, ids[3])
        XCTAssertEqual(state.selectedFrameIDs, [ids[3]])
        XCTAssertEqual(state.selectedFrameSelectionAnchorID, ids[3])
    }

    func testRangeSelectionUsesAnchorAndTarget() {
        let ids = makeFrameIDs(count: 5)
        var state = makeState(ids, selectedFrameID: ids[1], selectedFrameIDs: [ids[1]], anchorID: ids[1])

        let outcome = CutWorkspaceFrameSelectionCoordinator.selectFrame(
            ids[4],
            modifiers: .range,
            in: &state
        )

        XCTAssertEqual(outcome, .changed(primaryFrameID: ids[4], previousPrimaryFrameID: ids[1]))
        XCTAssertEqual(state.selectedFrameIDs, [ids[1], ids[2], ids[3], ids[4]])
        XCTAssertEqual(state.selectedFrameSelectionAnchorID, ids[1])
    }

    func testAdjacentSelectionCollapsesMultiSelectionAndStopsAtEdges() {
        let ids = makeFrameIDs(count: 3)
        var state = makeState(ids, selectedFrameID: ids[1], selectedFrameIDs: [ids[0], ids[1]], anchorID: ids[0])

        let previous = CutWorkspaceFrameSelectionCoordinator.selectPreviousFrame(in: &state)

        XCTAssertEqual(previous, .changed(primaryFrameID: ids[0], previousPrimaryFrameID: ids[1]))
        XCTAssertEqual(state.selectedFrameIDs, [ids[0]])
        XCTAssertEqual(state.selectedFrameSelectionAnchorID, ids[0])

        let boundary = CutWorkspaceFrameSelectionCoordinator.selectPreviousFrame(in: &state)

        XCTAssertNil(boundary)
        XCTAssertEqual(state.selectedFrameID, ids[0])
        XCTAssertEqual(state.selectedFrameIDs, [ids[0]])
    }

    func testPlaybackAdvanceWrapsToFirstFrame() {
        let ids = makeFrameIDs(count: 3)
        var state = makeState(ids, selectedFrameID: ids[2], selectedFrameIDs: [ids[2]], anchorID: ids[2])

        let outcome = CutWorkspaceFrameSelectionCoordinator.advancePlaybackFrame(in: &state)

        XCTAssertEqual(outcome, .changed(primaryFrameID: ids[0], previousPrimaryFrameID: ids[2]))
        XCTAssertEqual(state.selectedFrameID, ids[0])
        XCTAssertEqual(state.selectedFrameIDs, [ids[0]])
        XCTAssertEqual(state.selectedFrameSelectionAnchorID, ids[0])
    }

    func testCollapseSelectionUsesResolvedFallbackWhenSelectedFrameWasRemoved() {
        let ids = makeFrameIDs(count: 3)
        var state = CutWorkspaceFrameSelectionState(
            frames: ids.dropLast().map(CutWorkspaceFrameSelectionFrame.init(id:)),
            selectedFrameID: ids[2],
            selectedFrameIDs: [ids[1], ids[2]],
            selectedFrameSelectionAnchorID: ids[2],
            lastOpenedFrameID: ids[1]
        )

        CutWorkspaceFrameSelectionCoordinator.collapseSelectionToPrimaryFrame(in: &state)

        XCTAssertEqual(state.selectedFrameID, ids[1])
        XCTAssertEqual(state.selectedFrameIDs, [ids[1]])
        XCTAssertEqual(state.selectedFrameSelectionAnchorID, ids[1])
        XCTAssertEqual(state.lastOpenedFrameID, ids[1])
    }

    func testRejectsMissingFrameWithoutMutatingSelection() {
        let ids = makeFrameIDs(count: 2)
        var state = makeState(ids, selectedFrameID: ids[0], selectedFrameIDs: [ids[0]], anchorID: ids[0])
        let snapshot = state

        let outcome = CutWorkspaceFrameSelectionCoordinator.selectFrame(UUID(), in: &state)

        XCTAssertEqual(outcome, .rejected)
        XCTAssertEqual(state, snapshot)
    }

    private func makeState(
        _ frameIDs: [UUID],
        selectedFrameID: UUID? = nil,
        selectedFrameIDs: Set<UUID> = [],
        anchorID: UUID? = nil,
        lastOpenedFrameID: UUID? = nil
    ) -> CutWorkspaceFrameSelectionState {
        let primary = selectedFrameID ?? frameIDs.first
        return CutWorkspaceFrameSelectionState(
            frames: frameIDs.map(CutWorkspaceFrameSelectionFrame.init(id:)),
            selectedFrameID: primary,
            selectedFrameIDs: selectedFrameIDs.isEmpty ? Set([primary].compactMap { $0 }) : selectedFrameIDs,
            selectedFrameSelectionAnchorID: anchorID ?? primary,
            lastOpenedFrameID: lastOpenedFrameID ?? primary
        )
    }

    private func makeFrameIDs(count: Int) -> [UUID] {
        (0..<count).map { index in
            UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index + 1))!
        }
    }
}
