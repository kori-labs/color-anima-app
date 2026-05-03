import XCTest
import ColorAnimaAppWorkspaceApplication

//         ProjectSessionModelExportActionsTests)
//
// These tests exercise ProjectSessionCoordinator over public app-side DTOs only.
// Scenarios that required banned source-only types (workspace cut model, raster
// bitmap value type, imported artwork model) or kernel-side persistence I/O are

final class ProjectSessionCoordinatorTests: XCTestCase {

    // MARK: - Session lifecycle: initial selection

    func testInitialStateSelectsLastOpenedCutWhenPresent() {
        let cutID1 = UUID()
        let cutID2 = UUID()
        let document = makeDocument(cutIDs: [cutID1, cutID2], lastOpenedCutID: cutID2)
        let state = ProjectSessionCoordinator.makeInitialState(document: document)

        XCTAssertEqual(state.activeCutID, cutID2)
        XCTAssertEqual(state.selectedNodeID, cutID2)
    }

    func testInitialStateSelectsFirstCutWhenNoLastOpenedCutID() {
        let cutID1 = UUID()
        let cutID2 = UUID()
        let document = makeDocument(cutIDs: [cutID1, cutID2], lastOpenedCutID: nil)
        let state = ProjectSessionCoordinator.makeInitialState(document: document)

        XCTAssertEqual(state.activeCutID, cutID1)
        XCTAssertEqual(state.selectedNodeID, cutID1)
    }

    func testInitialStateSelectsProjectRootWhenNoCutsExist() {
        let projectID = UUID()
        let document = ProjectSessionDocumentSnapshot(
            projectID: projectID,
            projectName: "Empty Project",
            rootNode: WorkspaceProjectTreeNode(
                id: projectID,
                kind: .project,
                name: "Empty Project",
                children: []
            )
        )
        let state = ProjectSessionCoordinator.makeInitialState(document: document)

        XCTAssertNil(state.activeCutID)
        XCTAssertEqual(state.selectedNodeID, projectID)
    }

    // MARK: - Node selection: cut selection activates, non-cut clears

    func testSelectNodeCutActivatesEditor() {
        let cutID = UUID()
        let sceneID = UUID()
        let document = makeDocument(cutIDs: [cutID], sceneID: sceneID, lastOpenedCutID: cutID)
        var state = ProjectSessionCoordinator.makeInitialState(document: document)

        XCTAssertEqual(state.activeCutID, cutID)

        ProjectSessionCoordinator.selectNode(sceneID, in: &state)
        XCTAssertNil(state.activeCutID)

        ProjectSessionCoordinator.selectNode(cutID, in: &state)
        XCTAssertEqual(state.activeCutID, cutID)
    }

    // MARK: - Dirty tracking

    func testMarkDirtyAndHasUnsavedChanges() {
        let cutID = UUID()
        let document = makeDocument(cutIDs: [cutID], lastOpenedCutID: cutID)
        var state = ProjectSessionCoordinator.makeInitialState(document: document)

        XCTAssertFalse(state.hasUnsavedChanges)

        ProjectSessionCoordinator.markDirty(cutID: cutID, in: &state)

        XCTAssertTrue(state.hasUnsavedChanges)
        XCTAssertTrue(state.dirtyCutIDs.contains(cutID))
    }

    func testMarkCutSavedClearsFromDirtyCutIDs() {
        let cutID = UUID()
        let document = makeDocument(cutIDs: [cutID], lastOpenedCutID: cutID)
        var state = ProjectSessionCoordinator.makeInitialState(document: document)
        ProjectSessionCoordinator.markDirty(cutID: cutID, in: &state)
        XCTAssertTrue(state.dirtyCutIDs.contains(cutID))

        ProjectSessionCoordinator.markCutSaved(cutID: cutID, in: &state)

        XCTAssertFalse(state.dirtyCutIDs.contains(cutID))
        XCTAssertFalse(state.hasUnsavedChanges)
    }

    func testMarkMetadataDirtyAndSaved() {
        let document = makeDocument(cutIDs: [UUID()], lastOpenedCutID: nil)
        var state = ProjectSessionCoordinator.makeInitialState(document: document)

        XCTAssertFalse(state.metadataDirty)

        ProjectSessionCoordinator.markMetadataDirty(in: &state)
        XCTAssertTrue(state.metadataDirty)
        XCTAssertTrue(state.hasUnsavedChanges)

        ProjectSessionCoordinator.markMetadataSaved(in: &state)
        XCTAssertFalse(state.metadataDirty)
    }

    // MARK: - Pending close request

    func testRequestCloseReturnsTrueWhenNoUnsavedChanges() {
        let cutID = UUID()
        let document = makeDocument(cutIDs: [cutID], lastOpenedCutID: cutID)
        var state = ProjectSessionCoordinator.makeInitialState(document: document)

        let canClose = ProjectSessionCoordinator.requestClose(in: &state)

        XCTAssertTrue(canClose)
        XCTAssertNil(state.pendingCloseRequest)
    }

    func testRequestCloseCreatesPendingCloseRequestWhenDirty() {
        let cutID = UUID()
        let document = makeDocument(cutIDs: [cutID], lastOpenedCutID: cutID)
        var state = ProjectSessionCoordinator.makeInitialState(document: document)
        ProjectSessionCoordinator.markDirty(cutID: cutID, in: &state)

        let canClose = ProjectSessionCoordinator.requestClose(in: &state)

        XCTAssertFalse(canClose)
        XCTAssertEqual(state.pendingCloseRequest?.dirtyCutIDs, [cutID])
    }

    func testDismissCloseRequestClearsPendingCloseRequest() {
        let cutID = UUID()
        let document = makeDocument(cutIDs: [cutID], lastOpenedCutID: cutID)
        var state = ProjectSessionCoordinator.makeInitialState(document: document)
        ProjectSessionCoordinator.markDirty(cutID: cutID, in: &state)
        ProjectSessionCoordinator.requestClose(in: &state)
        XCTAssertNotNil(state.pendingCloseRequest)

        ProjectSessionCoordinator.dismissCloseRequest(in: &state)

        XCTAssertNil(state.pendingCloseRequest)
    }

    // MARK: - Region rewrite generation

    func testIncrementRegionRewriteGenerationReturnsNewValue() {
        let document = makeDocument(cutIDs: [], lastOpenedCutID: nil)
        var state = ProjectSessionCoordinator.makeInitialState(document: document)

        XCTAssertEqual(state.regionRewriteGeneration, 0)

        let gen1 = ProjectSessionCoordinator.incrementRegionRewriteGeneration(in: &state)
        XCTAssertEqual(gen1, 1)
        XCTAssertEqual(state.regionRewriteGeneration, 1)

        let gen2 = ProjectSessionCoordinator.incrementRegionRewriteGeneration(in: &state)
        XCTAssertEqual(gen2, 2)
    }

    func testApplyPartialRePropagationFeedbackIsDiscardedForStaleGeneration() {
        let document = makeDocument(cutIDs: [], lastOpenedCutID: nil)
        var state = ProjectSessionCoordinator.makeInitialState(document: document)

        let gen1 = ProjectSessionCoordinator.incrementRegionRewriteGeneration(in: &state)
        _ = ProjectSessionCoordinator.incrementRegionRewriteGeneration(in: &state)

        // Apply feedback for generation 1 — should be discarded because gen 2 is current.
        ProjectSessionCoordinator.applyPartialRePropagationFeedback(
            "stale feedback",
            generation: gen1,
            in: &state
        )

        XCTAssertNil(state.partialRePropagationFeedback)
    }

    func testApplyPartialRePropagationFeedbackIsAppliedForCurrentGeneration() {
        let document = makeDocument(cutIDs: [], lastOpenedCutID: nil)
        var state = ProjectSessionCoordinator.makeInitialState(document: document)

        let gen = ProjectSessionCoordinator.incrementRegionRewriteGeneration(in: &state)

        ProjectSessionCoordinator.applyPartialRePropagationFeedback(
            "re-propagated 3 frames",
            generation: gen,
            in: &state
        )

        XCTAssertEqual(state.partialRePropagationFeedback, "re-propagated 3 frames")
    }

    // MARK: - Export request surface

    func testMakeExportRequestSucceedsForKnownCutID() {
        let cutID = UUID()
        let document = makeDocument(cutIDs: [cutID], lastOpenedCutID: cutID)
        let state = ProjectSessionCoordinator.makeInitialState(document: document)

        let result = ProjectSessionCoordinator.makeExportRequest(for: cutID, in: state)

        guard case let .success(request) = result else {
            XCTFail("Expected success but got \(result)")
            return
        }
        XCTAssertEqual(request.cutID, cutID)
    }

    func testMakeExportRequestFailsForUnknownCutID() {
        let cutID = UUID()
        let unknownID = UUID()
        let document = makeDocument(cutIDs: [cutID], lastOpenedCutID: cutID)
        let state = ProjectSessionCoordinator.makeInitialState(document: document)

        let result = ProjectSessionCoordinator.makeExportRequest(for: unknownID, in: state)

        guard case let .failure(error) = result else {
            XCTFail("Expected failure but got \(result)")
            return
        }
        XCTAssertEqual(error, .cutNotFound(unknownID))
    }

    // MARK: - Document update

    func testUpdateDocumentNormalizesSelectionAfterStructureChange() {
        let cutID1 = UUID()
        let cutID2 = UUID()
        let document = makeDocument(cutIDs: [cutID1, cutID2], lastOpenedCutID: cutID1)
        var state = ProjectSessionCoordinator.makeInitialState(document: document)
        XCTAssertEqual(state.activeCutID, cutID1)

        // Build a new document without cutID1 (simulates cut deletion).
        let newDocument = makeDocument(cutIDs: [cutID2], lastOpenedCutID: nil)
        ProjectSessionCoordinator.updateDocument(newDocument, in: &state)

        XCTAssertEqual(state.activeCutID, cutID2)
    }

    // MARK: - Ordered dirty cut IDs

    func testOrderedDirtyCutIDsReturnsSortedByUUIDString() {
        let ids = [
            UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
            UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!,
            UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!,
        ]
        let document = makeDocument(cutIDs: ids, lastOpenedCutID: nil)
        var state = ProjectSessionCoordinator.makeInitialState(document: document)
        for id in ids { ProjectSessionCoordinator.markDirty(cutID: id, in: &state) }

        XCTAssertEqual(state.orderedDirtyCutIDs, ids.sorted { $0.uuidString < $1.uuidString })
    }
}

// MARK: - Helpers

private func makeDocument(
    cutIDs: [UUID],
    sceneID: UUID? = nil,
    lastOpenedCutID: UUID?
) -> ProjectSessionDocumentSnapshot {
    let projectID = UUID()
    let resolvedSceneID = sceneID ?? UUID()
    let sequenceID = UUID()

    let cutNodes = cutIDs.map {
        WorkspaceProjectTreeNode(id: $0, kind: .cut, name: "CUT")
    }
    let sceneNode = WorkspaceProjectTreeNode(
        id: resolvedSceneID,
        kind: .scene,
        name: "SC001",
        children: cutNodes
    )
    let sequenceNode = WorkspaceProjectTreeNode(
        id: sequenceID,
        kind: .sequence,
        name: "SQ001",
        children: [sceneNode]
    )
    let rootNode = WorkspaceProjectTreeNode(
        id: projectID,
        kind: .project,
        name: "Test Project",
        children: cutIDs.isEmpty ? [] : [sequenceNode]
    )

    return ProjectSessionDocumentSnapshot(
        projectID: projectID,
        projectName: "Test Project",
        rootNode: rootNode,
        lastOpenedCutID: lastOpenedCutID
    )
}
