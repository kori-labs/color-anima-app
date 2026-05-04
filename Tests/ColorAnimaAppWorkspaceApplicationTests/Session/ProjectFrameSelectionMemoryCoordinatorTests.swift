import XCTest
@testable import ColorAnimaAppWorkspaceApplication

final class ProjectFrameSelectionMemoryCoordinatorTests: XCTestCase {
    func testSyncFrameSelectionStateStoresPrimarySetAnchorAndOrder() {
        let cutID = UUID()
        let ids = makeFrameIDs()
        let workspace = ProjectFrameSelectionMemoryWorkspaceState(
            frameIDsInDisplayOrder: ids,
            selectedFrameID: ids[2],
            selectedFrameIDs: [ids[0], ids[2]],
            selectedFrameSelectionAnchorID: ids[0]
        )
        var state = ProjectFrameSelectionMemoryState()

        ProjectFrameSelectionMemoryCoordinator.syncFrameSelectionState(
            for: cutID,
            workspace: workspace,
            in: &state
        )

        XCTAssertEqual(state.selectedFrameIDByCutID[cutID], ids[2])
        XCTAssertEqual(state.selectedFrameIDsByCutID[cutID], [ids[0], ids[2]])
        XCTAssertEqual(state.frameSelectionAnchorByCutID[cutID], ids[0])
        XCTAssertEqual(state.selectedFrameSelectionOrderByCutID[cutID], [ids[0], ids[2]])
    }

    func testSyncFrameSelectionStatePreservesPreferredOrderWhenSelectionChanges() {
        let cutID = UUID()
        let ids = makeFrameIDs()
        let workspace = ProjectFrameSelectionMemoryWorkspaceState(
            frameIDsInDisplayOrder: ids,
            selectedFrameID: ids[1],
            selectedFrameIDs: [ids[0], ids[1], ids[2]],
            selectedFrameSelectionAnchorID: ids[1]
        )
        var state = ProjectFrameSelectionMemoryState(
            selectedFrameSelectionOrderByCutID: [cutID: [ids[2], ids[0]]]
        )

        ProjectFrameSelectionMemoryCoordinator.syncFrameSelectionState(
            for: cutID,
            workspace: workspace,
            in: &state
        )

        XCTAssertEqual(state.selectedFrameSelectionOrderByCutID[cutID], [ids[2], ids[0], ids[1]])
    }

    func testSyncFrameSelectionStateClearsMissingSelectionEntries() {
        let cutID = UUID()
        let ids = makeFrameIDs()
        var state = ProjectFrameSelectionMemoryState(
            selectedFrameIDByCutID: [cutID: ids[0]],
            selectedFrameIDsByCutID: [cutID: [ids[0]]],
            frameSelectionAnchorByCutID: [cutID: ids[0]],
            selectedFrameSelectionOrderByCutID: [cutID: [ids[0]]]
        )
        let workspace = ProjectFrameSelectionMemoryWorkspaceState(frameIDsInDisplayOrder: ids)

        ProjectFrameSelectionMemoryCoordinator.syncFrameSelectionState(
            for: cutID,
            workspace: workspace,
            in: &state
        )

        XCTAssertNil(state.selectedFrameIDByCutID[cutID])
        XCTAssertNil(state.selectedFrameIDsByCutID[cutID])
        XCTAssertNil(state.frameSelectionAnchorByCutID[cutID])
        XCTAssertNil(state.selectedFrameSelectionOrderByCutID[cutID])
    }

    func testResolveFrameSelectionOrderAddsAndRemovesAdditiveSelectionInUserOrder() {
        let cutID = UUID()
        let ids = makeFrameIDs()
        let workspace = ProjectFrameSelectionMemoryWorkspaceState(
            frameIDsInDisplayOrder: ids,
            selectedFrameID: ids[2],
            selectedFrameIDs: [ids[0], ids[2]],
            selectedFrameSelectionAnchorID: ids[2]
        )
        let state = ProjectFrameSelectionMemoryState(
            selectedFrameSelectionOrderByCutID: [cutID: [ids[0], ids[2]]]
        )

        let added = ProjectFrameSelectionMemoryCoordinator.resolveFrameSelectionOrder(
            for: ids[1],
            modifiers: .additive,
            in: workspace,
            cutID: cutID,
            state: state
        )
        let removed = ProjectFrameSelectionMemoryCoordinator.resolveFrameSelectionOrder(
            for: ids[0],
            modifiers: .additive,
            in: workspace,
            cutID: cutID,
            state: state
        )

        XCTAssertEqual(added, [ids[0], ids[2], ids[1]])
        XCTAssertEqual(removed, [ids[2]])
    }

    func testResolveFrameSelectionOrderUsesRangeWhenAnchorIsAvailable() {
        let cutID = UUID()
        let ids = makeFrameIDs()
        let workspace = ProjectFrameSelectionMemoryWorkspaceState(
            frameIDsInDisplayOrder: ids,
            selectedFrameID: ids[1],
            selectedFrameIDs: [ids[1]],
            selectedFrameSelectionAnchorID: ids[1]
        )

        let order = ProjectFrameSelectionMemoryCoordinator.resolveFrameSelectionOrder(
            for: ids[3],
            modifiers: .range,
            in: workspace,
            cutID: cutID,
            state: ProjectFrameSelectionMemoryState()
        )

        XCTAssertEqual(order, [ids[1], ids[2], ids[3]])
    }

    func testOrderedSelectedFrameIDsFiltersInvalidIDsAndUsesPersistedOrder() {
        let cutID = UUID()
        let ids = makeFrameIDs()
        let unknownID = UUID()
        let state = ProjectFrameSelectionMemoryState(
            workspaces: [
                cutID: ProjectFrameSelectionMemoryWorkspaceState(frameIDsInDisplayOrder: ids)
            ],
            selectedFrameSelectionOrderByCutID: [cutID: [ids[2], unknownID, ids[0]]]
        )

        let ordered = ProjectFrameSelectionMemoryCoordinator.orderedSelectedFrameIDs(
            for: cutID,
            selection: [ids[0], ids[2], unknownID],
            primaryID: ids[1],
            in: state
        )

        XCTAssertEqual(ordered, [ids[2], ids[0], ids[1]])
    }

    func testPruneToValidCutIDsDropsRemovedCutAndRepairsSelection() {
        let cutA = UUID(uuidString: "00000000-0000-0000-0000-0000000A0001")!
        let cutB = UUID(uuidString: "00000000-0000-0000-0000-0000000B0001")!
        let ids = makeFrameIDs()
        let staleID = UUID(uuidString: "00000000-0000-0000-0000-0000DEAD0001")!

        // cutA: frames ids[0], ids[1], ids[2]; staleID is in selection/anchor but not in frameIDsInDisplayOrder
        let workspaceA = ProjectFrameSelectionMemoryWorkspaceState(
            frameIDsInDisplayOrder: [ids[0], ids[1], ids[2]]
        )
        // cutB: present in all dicts; should be fully removed
        let workspaceB = ProjectFrameSelectionMemoryWorkspaceState(
            frameIDsInDisplayOrder: [ids[3]]
        )

        var state = ProjectFrameSelectionMemoryState(
            workspaces: [cutA: workspaceA, cutB: workspaceB],
            selectedFrameIDByCutID: [cutA: staleID, cutB: ids[3]],
            selectedFrameIDsByCutID: [cutA: [ids[0], staleID], cutB: [ids[3]]],
            frameSelectionAnchorByCutID: [cutA: staleID, cutB: ids[3]],
            selectedFrameSelectionOrderByCutID: [cutA: [ids[0], staleID], cutB: [ids[3]]]
        )

        ProjectFrameSelectionMemoryCoordinator.pruneToValidCutIDs([cutA], in: &state)

        // cutB must be removed from all five dicts
        XCTAssertNil(state.workspaces[cutB])
        XCTAssertNil(state.selectedFrameIDByCutID[cutB])
        XCTAssertNil(state.selectedFrameIDsByCutID[cutB])
        XCTAssertNil(state.frameSelectionAnchorByCutID[cutB])
        XCTAssertNil(state.selectedFrameSelectionOrderByCutID[cutB])

        // cutA: stale frame removed from multi-selection
        XCTAssertEqual(state.selectedFrameIDsByCutID[cutA], [ids[0]])

        // cutA: primary was the stale frame — must be updated to a valid frame
        let repairedPrimary = state.selectedFrameIDByCutID[cutA]
        XCTAssertNotNil(repairedPrimary)
        XCTAssertNotEqual(repairedPrimary, staleID)
        XCTAssertEqual(repairedPrimary, ids[0])

        // cutA: anchor was the stale frame — must be updated to a valid frame
        let repairedAnchor = state.frameSelectionAnchorByCutID[cutA]
        XCTAssertNotNil(repairedAnchor)
        XCTAssertNotEqual(repairedAnchor, staleID)

        // cutA: order must not contain the stale frame
        let order = state.selectedFrameSelectionOrderByCutID[cutA]
        XCTAssertNotNil(order)
        XCTAssertFalse(order?.contains(staleID) ?? false)
    }

    func testContiguousFrameIDsReturnsNilForMissingEndpoints() {
        let ids = makeFrameIDs()

        XCTAssertNil(
            ProjectFrameSelectionMemoryCoordinator.contiguousFrameIDs(
                between: ids[0],
                and: UUID(),
                in: ids
            )
        )
    }

    private func makeFrameIDs() -> [UUID] {
        [
            UUID(uuidString: "00000000-0000-0000-0000-000000100001")!,
            UUID(uuidString: "00000000-0000-0000-0000-000000100002")!,
            UUID(uuidString: "00000000-0000-0000-0000-000000100003")!,
            UUID(uuidString: "00000000-0000-0000-0000-000000100004")!
        ]
    }
}
