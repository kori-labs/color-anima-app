import CoreGraphics
import XCTest
@testable import ColorAnimaAppWorkspaceApplication

// Covers surviving (non-prewarm-cache, non-banned-type) cases from:
//   1. EditingProductivityRegressionTests  (#76 Selection Toggle/Range, #76 DnD, #95 Delete, #94 Batch, #93 Shortcut)
//   2. InspectorRegionSelectionRegressionTests (coordinator-routed modifier selection state — non-cache assertions)
// Two upstream sources are excluded entirely (banned-type dependencies — see internal ledger):
//   - CutWorkspaceRegionCoordinatorRegressionTests
//   - CutWorkspaceModelSelectionTests

@MainActor
final class RegionSelectionCoordinatorTests: XCTestCase {

    // MARK: - Plain single-select

    func testPlainSelectSetsPrimaryAndAnchor() {
        let regionA = makeRegion(centroid: CGPoint(x: 0.2, y: 0.2))
        let regionB = makeRegion(centroid: CGPoint(x: 0.8, y: 0.8))
        let regions = [regionA, regionB]
        var state = RegionSelectionState.empty

        RegionSelectionCoordinator.selectRegion(withID: regionA.id, in: regions, state: &state)

        XCTAssertEqual(state.selectedRegionID, regionA.id)
        XCTAssertEqual(state.selectedRegionIDs, [regionA.id])
        XCTAssertEqual(state.selectedRegionAnchorID, regionA.id)
    }

    func testPlainSelectNilClearsSelection() {
        let region = makeRegion()
        let regions = [region]
        var state = makeState(selectedID: region.id, regions: regions)

        RegionSelectionCoordinator.selectRegion(withID: nil, in: regions, state: &state)

        XCTAssertNil(state.selectedRegionID)
        XCTAssertTrue(state.selectedRegionIDs.isEmpty)
        XCTAssertNil(state.selectedRegionAnchorID)
    }

    // MARK: - #76 Cmd-click toggle  (EditingProductivityRegressionTests)

    func testCmdClickTogglesRegionInAndOutOfSelection() {
        let regionA = makeRegion(centroid: CGPoint(x: 0.2, y: 0.2))
        let regionB = makeRegion(centroid: CGPoint(x: 0.8, y: 0.8))
        let regions = [regionA, regionB]
        var state = RegionSelectionState.empty

        // Select A normally
        RegionSelectionCoordinator.selectRegion(withID: regionA.id, in: regions, state: &state)
        XCTAssertEqual(state.selectedRegionIDs, [regionA.id])
        XCTAssertEqual(state.selectedRegionID, regionA.id)

        // Cmd-click B to add
        RegionSelectionCoordinator.selectRegion(
            withID: regionB.id,
            modifiers: .additive,
            in: regions,
            state: &state
        )
        XCTAssertEqual(state.selectedRegionIDs, [regionA.id, regionB.id])
        XCTAssertEqual(state.selectedRegionID, regionB.id)

        // Cmd-click A to remove
        RegionSelectionCoordinator.selectRegion(
            withID: regionA.id,
            modifiers: .additive,
            in: regions,
            state: &state
        )
        XCTAssertEqual(state.selectedRegionIDs, [regionB.id])
    }

    // MARK: - #76 Shift-click range  (EditingProductivityRegressionTests)

    func testShiftClickSelectsRangeFromAnchorToClickedRegion() {
        let regionA = makeRegion(centroid: CGPoint(x: 0.1, y: 0.1))
        let regionB = makeRegion(centroid: CGPoint(x: 0.3, y: 0.3))
        let regionC = makeRegion(centroid: CGPoint(x: 0.5, y: 0.5), isBackgroundCandidate: true)
        let regionD = makeRegion(centroid: CGPoint(x: 0.7, y: 0.7))
        let regions = [regionA, regionB, regionC, regionD]
        var state = RegionSelectionState.empty

        // Select B as anchor
        RegionSelectionCoordinator.selectRegion(withID: regionB.id, in: regions, state: &state)
        XCTAssertEqual(state.selectedRegionAnchorID, regionB.id)

        // Shift-click D to select range B..D (bounding box covers B, C, D)
        RegionSelectionCoordinator.selectRegion(
            withID: regionD.id,
            modifiers: .range,
            in: regions,
            state: &state
        )
        XCTAssertEqual(state.selectedRegionIDs, [regionB.id, regionC.id, regionD.id])
        XCTAssertEqual(state.selectedRegionID, regionD.id)
        // Anchor must remain B
        XCTAssertEqual(state.selectedRegionAnchorID, regionB.id)
    }

    func testPlainClickResetsSingleSelection() {
        let regionA = makeRegion(centroid: CGPoint(x: 0.2, y: 0.2))
        let regionB = makeRegion(centroid: CGPoint(x: 0.8, y: 0.8))
        let regions = [regionA, regionB]
        var state = RegionSelectionState.empty

        // Build multi-select
        RegionSelectionCoordinator.selectRegion(withID: regionA.id, in: regions, state: &state)
        RegionSelectionCoordinator.selectRegion(
            withID: regionB.id,
            modifiers: .additive,
            in: regions,
            state: &state
        )
        XCTAssertEqual(state.selectedRegionIDs.count, 2)

        // Plain click B — should reset to single
        RegionSelectionCoordinator.selectRegion(
            withID: regionB.id,
            modifiers: [],
            in: regions,
            state: &state
        )
        XCTAssertEqual(state.selectedRegionIDs, [regionB.id])
        XCTAssertEqual(state.selectedRegionID, regionB.id)
    }

    // MARK: - #76 Region-row drop assigns only dropped row  (EditingProductivityRegressionTests)

    func testAssignRegionByIDTargetsOnlyThatRegionNotFullSelection() {
        let groupID = UUID()
        let subsetID = UUID()
        let regionA = makeRegion(centroid: CGPoint(x: 0.2, y: 0.2))
        let regionB = makeRegion(centroid: CGPoint(x: 0.8, y: 0.8))
        var regions = [regionA, regionB]
        var state = RegionSelectionState.empty

        // Multi-select both
        RegionSelectionCoordinator.selectRegion(withID: regionA.id, in: regions, state: &state)
        RegionSelectionCoordinator.selectRegion(
            withID: regionB.id,
            modifiers: .additive,
            in: regions,
            state: &state
        )

        // Assign only region B by ID (simulates row drop)
        RegionSelectionCoordinator.assignRegion(
            withID: regionB.id,
            groupID: groupID,
            subsetID: subsetID,
            statusName: "default",
            in: &regions
        )

        XCTAssertNil(regions.first(where: { $0.id == regionA.id })?.assignment)
        XCTAssertNotNil(regions.first(where: { $0.id == regionB.id })?.assignment)
        XCTAssertEqual(regions.first(where: { $0.id == regionB.id })?.assignment?.subsetID, subsetID)
    }

    // MARK: - #95 Delete removes region + clears selection  (EditingProductivityRegressionTests)

    func testDeleteSelectedRegionRemovesRegionAndClearsSelection() {
        let groupID = UUID()
        let subsetID = UUID()
        let region = makeRegion(
            centroid: CGPoint(x: 0.5, y: 0.5),
            assignment: RegionSelectionAssignment(groupID: groupID, subsetID: subsetID, statusName: "default")
        )
        var regions = [region]
        var state = RegionSelectionState.empty

        RegionSelectionCoordinator.selectRegion(withID: region.id, in: regions, state: &state)
        XCTAssertEqual(state.selectedRegionID, region.id)

        RegionSelectionCoordinator.deleteSelectedRegions(in: &regions, state: &state)

        XCTAssertTrue(regions.isEmpty)
        XCTAssertNil(state.selectedRegionID)
        XCTAssertTrue(state.selectedRegionIDs.isEmpty)
    }

    func testDeleteMultiSelectRemovesFullSet() {
        let regionA = makeRegion(centroid: CGPoint(x: 0.2, y: 0.2))
        let regionB = makeRegion(centroid: CGPoint(x: 0.5, y: 0.5))
        let regionC = makeRegion(centroid: CGPoint(x: 0.8, y: 0.8))
        var regions = [regionA, regionB, regionC]
        var state = RegionSelectionState.empty

        // Select A and B
        RegionSelectionCoordinator.selectRegion(withID: regionA.id, in: regions, state: &state)
        RegionSelectionCoordinator.selectRegion(
            withID: regionB.id,
            modifiers: .additive,
            in: regions,
            state: &state
        )

        RegionSelectionCoordinator.deleteSelectedRegions(in: &regions, state: &state)

        XCTAssertEqual(regions.count, 1)
        XCTAssertEqual(regions.first?.id, regionC.id)
        XCTAssertNil(state.selectedRegionID)
        XCTAssertTrue(state.selectedRegionIDs.isEmpty)
    }

    // MARK: - #94 Batch assign applies to selected set  (EditingProductivityRegressionTests)

    func testBatchAssignAppliesToSelectedSet() {
        let groupID = UUID()
        let subsetID = UUID()
        let regionA = makeRegion(centroid: CGPoint(x: 0.2, y: 0.2))
        let regionB = makeRegion(centroid: CGPoint(x: 0.5, y: 0.5))
        let bgRegion = makeRegion(centroid: CGPoint(x: 0.8, y: 0.8), isBackgroundCandidate: true)
        let regionC = makeRegion(centroid: CGPoint(x: 0.9, y: 0.9))
        var regions = [regionA, regionB, bgRegion, regionC]
        var state = RegionSelectionState.empty

        RegionSelectionCoordinator.selectRegion(withID: regionA.id, in: regions, state: &state)
        RegionSelectionCoordinator.selectRegion(
            withID: regionB.id,
            modifiers: .additive,
            in: regions,
            state: &state
        )
        RegionSelectionCoordinator.selectRegion(
            withID: bgRegion.id,
            modifiers: .additive,
            in: regions,
            state: &state
        )

        RegionSelectionCoordinator.batchAssignSelectedRegions(
            groupID: groupID,
            subsetID: subsetID,
            statusName: "default",
            in: &regions,
            state: state
        )

        XCTAssertEqual(regions.first(where: { $0.id == regionA.id })?.assignment?.subsetID, subsetID)
        XCTAssertEqual(regions.first(where: { $0.id == regionB.id })?.assignment?.subsetID, subsetID)
        XCTAssertEqual(regions.first(where: { $0.id == bgRegion.id })?.assignment?.subsetID, subsetID)
        XCTAssertNil(regions.first(where: { $0.id == regionC.id })?.assignment)
    }

    // MARK: - #93 Shortcut catalog and no-op safety  (EditingProductivityRegressionTests)

    func testShortcutCatalogIncludesAssignSubsetCommand() {
        let definition = WorkspaceShortcutDefinition.catalog.first(where: {
            $0.command == .assignSubsetToSelectedRegions
        })
        XCTAssertNotNil(definition)
        XCTAssertEqual(definition?.ownership, .globalCoordinator)
        XCTAssertTrue(definition?.bindings.contains(.keyDown(keyCode: 0)) == true)
    }

    func testAssignShortcutIsNoOpWhenNoRegionSelected() {
        var regions = [makeRegion()]
        let state = RegionSelectionState.empty   // nothing selected

        let regionsBefore = regions

        RegionSelectionCoordinator.batchAssignSelectedRegions(
            groupID: UUID(),
            subsetID: UUID(),
            statusName: "default",
            in: &regions,
            state: state
        )

        XCTAssertEqual(regions.map(\.id), regionsBefore.map(\.id))
        XCTAssertNil(regions.first?.assignment)
    }

    // MARK: - Coordinator-routed modifier selection state assertions
    //         (InspectorRegionSelectionRegressionTests — non-cache subset)

    func testSingleSelectViaCoordinatorSetsBothSelectionFields() {
        let (regions, regionID) = makeTwoRegions()
        var state = RegionSelectionState.empty

        RegionSelectionCoordinator.selectRegion(withID: regionID.0, in: regions, state: &state)

        XCTAssertEqual(state.selectedRegionID, regionID.0)
        XCTAssertEqual(state.selectedRegionIDs, [regionID.0])
        XCTAssertEqual(state.selectedRegionAnchorID, regionID.0)
    }

    func testCmdClickAddsRegionToSelection() {
        let (regions, ids) = makeTwoRegions()
        var state = RegionSelectionState.empty

        RegionSelectionCoordinator.selectRegion(withID: ids.0, in: regions, state: &state)
        RegionSelectionCoordinator.selectRegion(
            withID: ids.1,
            modifiers: .additive,
            in: regions,
            state: &state
        )

        XCTAssertTrue(state.selectedRegionIDs.contains(ids.0))
        XCTAssertTrue(state.selectedRegionIDs.contains(ids.1))
        XCTAssertEqual(state.selectedRegionID, ids.1)
        XCTAssertEqual(state.selectedRegionAnchorID, ids.1)
    }

    func testCmdClickOnSelectedRegionDeselectsIt() {
        let (regions, ids) = makeTwoRegions()
        var state = RegionSelectionState.empty

        RegionSelectionCoordinator.selectRegion(withID: ids.0, in: regions, state: &state)
        RegionSelectionCoordinator.selectRegion(
            withID: ids.1,
            modifiers: .additive,
            in: regions,
            state: &state
        )
        XCTAssertEqual(state.selectedRegionIDs.count, 2, "Precondition: both selected")

        // Cmd-click the second region again to remove it
        RegionSelectionCoordinator.selectRegion(
            withID: ids.1,
            modifiers: .additive,
            in: regions,
            state: &state
        )

        XCTAssertFalse(state.selectedRegionIDs.contains(ids.1))
        XCTAssertTrue(state.selectedRegionIDs.contains(ids.0))
        XCTAssertEqual(state.selectedRegionID, ids.0)
    }

    func testCmdClickOnOnlySelectedRegionClearsSelection() {
        let region = makeRegion()
        let regions = [region]
        var state = RegionSelectionState.empty

        RegionSelectionCoordinator.selectRegion(withID: region.id, in: regions, state: &state)
        RegionSelectionCoordinator.selectRegion(
            withID: region.id,
            modifiers: .additive,
            in: regions,
            state: &state
        )

        XCTAssertTrue(state.selectedRegionIDs.isEmpty)
        XCTAssertNil(state.selectedRegionID)
        XCTAssertNil(state.selectedRegionAnchorID)
    }

    func testShiftClickViaCoordinatorPerformsBoundingBoxRangeSelect() {
        let (regions, ids) = makeTwoRegions()
        var state = RegionSelectionState.empty

        RegionSelectionCoordinator.selectRegion(withID: ids.0, in: regions, state: &state)
        XCTAssertEqual(state.selectedRegionAnchorID, ids.0, "Precondition: anchor set")

        RegionSelectionCoordinator.selectRegion(
            withID: ids.1,
            modifiers: .range,
            in: regions,
            state: &state
        )

        XCTAssertTrue(state.selectedRegionIDs.contains(ids.0))
        XCTAssertTrue(state.selectedRegionIDs.contains(ids.1))
        XCTAssertEqual(state.selectedRegionID, ids.1)
    }

    func testShiftClickWithoutPriorAnchorFallsBackToSingleSelect() {
        let region = makeRegion()
        let regions = [region]
        var state = RegionSelectionState.empty

        // No prior selection — anchor is nil
        RegionSelectionCoordinator.selectRegion(
            withID: region.id,
            modifiers: .range,
            in: regions,
            state: &state
        )

        XCTAssertEqual(state.selectedRegionID, region.id)
        XCTAssertEqual(state.selectedRegionIDs, [region.id])
    }

    func testShiftClickRangeSelectDoesNotModifyRegionData() {
        let (regions, ids) = makeTwoRegions()
        var state = RegionSelectionState.empty

        RegionSelectionCoordinator.selectRegion(withID: ids.0, in: regions, state: &state)
        let regionsBefore = regions   // regions array is unchanged by selection

        RegionSelectionCoordinator.selectRegion(
            withID: ids.1,
            modifiers: .range,
            in: regions,
            state: &state
        )

        XCTAssertEqual(regions.map(\.id), regionsBefore.map(\.id))
    }

    // MARK: - Clear selection  (InspectorRegionSelectionRegressionTests)

    func testClearSelectionResetsAllSelectionFields() {
        let region = makeRegion()
        let regions = [region]
        var state = makeState(selectedID: region.id, regions: regions)

        RegionSelectionCoordinator.clearSelectedRegion(in: regions, state: &state)

        XCTAssertNil(state.selectedRegionID)
        XCTAssertTrue(state.selectedRegionIDs.isEmpty)
        XCTAssertNil(state.selectedRegionAnchorID)
    }

    func testClearSelectionIsNoOpWhenAlreadyEmpty() {
        let regions = [makeRegion()]
        var state = RegionSelectionState.empty

        RegionSelectionCoordinator.clearSelectedRegion(in: regions, state: &state)

        XCTAssertNil(state.selectedRegionID)
        XCTAssertTrue(state.selectedRegionIDs.isEmpty)
    }

    // MARK: - Helpers

    private func makeRegion(
        centroid: CGPoint = CGPoint(x: 0.5, y: 0.5),
        isBackgroundCandidate: Bool = false,
        assignment: RegionSelectionAssignment? = nil
    ) -> RegionSelectionRegion {
        RegionSelectionRegion(
            centroid: centroid,
            isBackgroundCandidate: isBackgroundCandidate,
            assignment: assignment
        )
    }

    private func makeTwoRegions() -> ([RegionSelectionRegion], (UUID, UUID)) {
        let first = RegionSelectionRegion(centroid: CGPoint(x: 2, y: 2))
        let second = RegionSelectionRegion(centroid: CGPoint(x: 6, y: 6))
        return ([first, second], (first.id, second.id))
    }

    private func makeState(
        selectedID: UUID,
        regions: [RegionSelectionRegion]
    ) -> RegionSelectionState {
        RegionSelectionState(
            selectedRegionID: selectedID,
            selectedRegionIDs: [selectedID],
            selectedRegionAnchorID: selectedID
        )
    }
}
