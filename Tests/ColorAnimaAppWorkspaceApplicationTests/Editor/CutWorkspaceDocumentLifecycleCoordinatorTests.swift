import XCTest
@testable import ColorAnimaAppWorkspaceApplication

final class CutWorkspaceDocumentLifecycleCoordinatorTests: XCTestCase {
    func testReplaceDocumentNormalizesSelectionAndRequestsCacheResets() {
        let ids = makeFrameIDs(count: 2)
        let document = CutWorkspaceDocumentSnapshot(
            frames: [
                makeFrame(ids[1], orderIndex: 1),
                makeFrame(ids[0], orderIndex: 0),
            ],
            lastOpenedFrameID: ids[1]
        )
        let selectedRegionID = makeID(20)
        var state = CutWorkspaceDocumentLifecycleState(
            selectedFrameID: ids[0],
            selectedFrameIDs: [ids[0], ids[1]],
            selectedFrameSelectionAnchorID: ids[0],
            selectedRegionID: selectedRegionID,
            selectedRegionIDs: [selectedRegionID],
            selectedRegionAnchorID: selectedRegionID,
            isDirty: true,
            isFramePlaybackActive: true,
            errorMessage: "stale"
        )

        CutWorkspaceDocumentLifecycleCoordinator.replaceDocument(document, in: &state)

        XCTAssertEqual(state.document.orderedFrames.map(\.id), ids)
        XCTAssertEqual(state.selectedFrameID, ids[1])
        XCTAssertEqual(state.selectedFrameIDs, [ids[1]])
        XCTAssertEqual(state.selectedFrameSelectionAnchorID, ids[1])
        XCTAssertNil(state.selectedRegionID)
        XCTAssertEqual(state.selectedRegionIDs, [])
        XCTAssertNil(state.selectedRegionAnchorID)
        XCTAssertFalse(state.isDirty)
        XCTAssertFalse(state.isFramePlaybackActive)
        XCTAssertNil(state.errorMessage)
        XCTAssertTrue(state.needsArtworkCacheReset)
        XCTAssertTrue(state.needsCanvasPresentationCacheReset)
        XCTAssertTrue(state.needsCanvasPresentationReset)
        XCTAssertTrue(state.needsExtractionStateRefresh)
    }

    func testMakeDocumentSnapshotCarriesLayerVisibilityAndSelectedFrame() {
        let ids = makeFrameIDs(count: 2)
        let document = CutWorkspaceDocumentSnapshot(frames: ids.enumerated().map {
            makeFrame($0.element, orderIndex: $0.offset)
        })
        let visibility = LayerVisibility(showOutline: false, showShadowLine: false)

        let snapshot = CutWorkspaceDocumentLifecycleCoordinator.makeDocumentSnapshot(
            from: document,
            layerVisibility: visibility,
            selectedFrameID: ids[1]
        )

        XCTAssertEqual(snapshot.frames.map(\.id), ids)
        XCTAssertEqual(snapshot.layerVisibility, visibility)
        XCTAssertEqual(snapshot.lastOpenedFrameID, ids[1])
    }

    func testMarkSavedPrunesSelectionAndFallsBackToLastOpenedFrame() {
        let ids = makeFrameIDs(count: 4)
        let savedDocument = CutWorkspaceDocumentSnapshot(
            frames: [
                makeFrame(ids[0], orderIndex: 0),
                makeFrame(ids[2], orderIndex: 1),
                makeFrame(ids[3], orderIndex: 2),
            ],
            lastOpenedFrameID: ids[2]
        )
        var state = CutWorkspaceDocumentLifecycleState(
            selectedFrameID: ids[1],
            selectedFrameIDs: [ids[1], ids[2], ids[3]],
            selectedFrameSelectionAnchorID: ids[1],
            isDirty: true
        )

        CutWorkspaceDocumentLifecycleCoordinator.markSaved(with: savedDocument, in: &state)

        XCTAssertEqual(state.selectedFrameID, ids[2])
        XCTAssertEqual(state.selectedFrameIDs, [ids[2], ids[3]])
        XCTAssertEqual(state.selectedFrameSelectionAnchorID, ids[2])
        XCTAssertFalse(state.isDirty)
    }

    func testMarkSavedKeepsCurrentPrimaryAndValidAnchor() {
        let ids = makeFrameIDs(count: 3)
        let savedDocument = CutWorkspaceDocumentSnapshot(
            frames: ids.enumerated().map { makeFrame($0.element, orderIndex: $0.offset) },
            lastOpenedFrameID: ids[2]
        )
        var state = CutWorkspaceDocumentLifecycleState(
            selectedFrameID: ids[1],
            selectedFrameIDs: [ids[0], ids[1]],
            selectedFrameSelectionAnchorID: ids[0],
            isDirty: true
        )

        CutWorkspaceDocumentLifecycleCoordinator.markSaved(with: savedDocument, in: &state)

        XCTAssertEqual(state.selectedFrameID, ids[1])
        XCTAssertEqual(state.selectedFrameIDs, [ids[0], ids[1]])
        XCTAssertEqual(state.selectedFrameSelectionAnchorID, ids[0])
        XCTAssertFalse(state.isDirty)
    }

    func testMarkSavedDoesNotCollapseMultiFrameSelection() {
        let ids = makeFrameIDs(count: 3)
        let savedDocument = CutWorkspaceDocumentSnapshot(
            frames: ids.enumerated().map { makeFrame($0.element, orderIndex: $0.offset) },
            lastOpenedFrameID: ids[0]
        )
        var state = CutWorkspaceDocumentLifecycleState(
            selectedFrameID: ids[2],
            selectedFrameIDs: [ids[0], ids[1], ids[2]],
            selectedFrameSelectionAnchorID: ids[2],
            isDirty: true
        )

        CutWorkspaceDocumentLifecycleCoordinator.markSaved(with: savedDocument, in: &state)

        XCTAssertEqual(state.selectedFrameID, ids[2])
        XCTAssertEqual(state.selectedFrameIDs, [ids[0], ids[1], ids[2]])
        XCTAssertEqual(state.selectedFrameSelectionAnchorID, ids[2])
        XCTAssertFalse(state.isDirty)
    }

    func testMarkSavedWithoutDocumentOnlyClearsDirtyFlag() {
        let ids = makeFrameIDs(count: 1)
        var state = CutWorkspaceDocumentLifecycleState(
            selectedFrameID: ids[0],
            selectedFrameIDs: [ids[0]],
            isDirty: true
        )

        CutWorkspaceDocumentLifecycleCoordinator.markSaved(in: &state)

        XCTAssertEqual(state.selectedFrameID, ids[0])
        XCTAssertEqual(state.selectedFrameIDs, [ids[0]])
        XCTAssertFalse(state.isDirty)
    }

    private func makeFrameIDs(count: Int) -> [UUID] {
        (0..<count).map { makeID($0 + 1) }
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

    private func makeID(_ index: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index))!
    }
}
