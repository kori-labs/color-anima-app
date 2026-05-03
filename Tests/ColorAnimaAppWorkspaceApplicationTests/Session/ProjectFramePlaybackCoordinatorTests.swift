import XCTest
@testable import ColorAnimaAppWorkspaceApplication

final class ProjectFramePlaybackCoordinatorTests: XCTestCase {
    func testToggleStartsActiveCutPlaybackAndCollapsesSelection() {
        let cutID = makeID(1)
        let frameIDs = makeFrameIDs(count: 3)
        var state = ProjectFramePlaybackState(
            activeCutID: cutID,
            projectPlaybackFPS: 24,
            workspaces: [
                cutID: ProjectFramePlaybackWorkspaceState(
                    frameSelection: CutWorkspaceFrameSelectionState(
                        frames: frameIDs.map(CutWorkspaceFrameSelectionFrame.init(id:)),
                        selectedFrameID: frameIDs[1],
                        selectedFrameIDs: [frameIDs[0], frameIDs[1]],
                        selectedFrameSelectionAnchorID: frameIDs[0],
                        lastOpenedFrameID: frameIDs[1]
                    )
                ),
            ]
        )

        let result = ProjectFramePlaybackCoordinator.toggleFramePlayback(in: &state)

        XCTAssertEqual(
            result,
            .started(cutID: cutID, frameDurationNanoseconds: 41_666_666)
        )
        XCTAssertEqual(state.framePlaybackCutID, cutID)
        XCTAssertEqual(state.workspaces[cutID]?.isFramePlaybackActive, true)
        XCTAssertEqual(state.workspaces[cutID]?.frameSelection.selectedFrameID, frameIDs[1])
        XCTAssertEqual(state.workspaces[cutID]?.frameSelection.selectedFrameIDs, [frameIDs[1]])
        XCTAssertEqual(state.workspaces[cutID]?.frameSelection.selectedFrameSelectionAnchorID, frameIDs[1])
        XCTAssertTrue(state.needsActiveCutRefresh)
    }

    func testToggleStopsActivePlayback() {
        let cutID = makeID(1)
        var state = ProjectFramePlaybackState(
            activeCutID: cutID,
            framePlaybackCutID: cutID,
            workspaces: [
                cutID: ProjectFramePlaybackWorkspaceState(
                    frameSelection: makeSelectionState(),
                    isFramePlaybackActive: true
                ),
            ]
        )

        let result = ProjectFramePlaybackCoordinator.toggleFramePlayback(in: &state)

        XCTAssertEqual(result, .stopped(cutID: cutID))
        XCTAssertNil(state.framePlaybackCutID)
        XCTAssertEqual(state.workspaces[cutID]?.isFramePlaybackActive, false)
        XCTAssertTrue(state.needsActiveCutRefresh)
    }

    func testRestartOnlyStartsWhenExistingPlaybackCutIsStillActive() {
        let cutID = makeID(1)
        var state = ProjectFramePlaybackState(
            activeCutID: cutID,
            framePlaybackCutID: cutID,
            projectPlaybackFPS: 12,
            workspaces: [
                cutID: ProjectFramePlaybackWorkspaceState(
                    frameSelection: makeSelectionState(),
                    isFramePlaybackActive: true
                ),
            ]
        )

        let result = ProjectFramePlaybackCoordinator.restartFramePlaybackIfNeeded(in: &state)

        XCTAssertEqual(result, .started(cutID: cutID, frameDurationNanoseconds: 83_333_333))
        XCTAssertEqual(state.framePlaybackCutID, cutID)
        XCTAssertTrue(state.needsActiveCutRefresh)

        state.workspaces[cutID]?.isFramePlaybackActive = false
        state.needsActiveCutRefresh = false

        let ignored = ProjectFramePlaybackCoordinator.restartFramePlaybackIfNeeded(in: &state)

        XCTAssertEqual(ignored, .ignored)
        XCTAssertFalse(state.needsActiveCutRefresh)
    }

    func testAdvancePlaybackWrapsSelectionAndRequestsAssetLoadAndPrefetch() {
        let cutID = makeID(1)
        let frameIDs = makeFrameIDs(count: 3)
        var state = ProjectFramePlaybackState(
            activeCutID: cutID,
            framePlaybackCutID: cutID,
            workspaces: [
                cutID: ProjectFramePlaybackWorkspaceState(
                    frameSelection: CutWorkspaceFrameSelectionState(
                        frames: frameIDs.map(CutWorkspaceFrameSelectionFrame.init(id:)),
                        selectedFrameID: frameIDs[2],
                        selectedFrameIDs: [frameIDs[2]],
                        selectedFrameSelectionAnchorID: frameIDs[2],
                        lastOpenedFrameID: frameIDs[2]
                    ),
                    isFramePlaybackActive: true,
                    frameIDsRequiringAssetLoad: [frameIDs[0]]
                ),
            ]
        )

        let result = ProjectFramePlaybackCoordinator.advanceFramePlayback(for: cutID, in: &state)

        XCTAssertEqual(result.cutID, cutID)
        XCTAssertEqual(result.selectedFrameID, frameIDs[0])
        XCTAssertEqual(
            result.selectionOutcome,
            .changed(primaryFrameID: frameIDs[0], previousPrimaryFrameID: frameIDs[2])
        )
        XCTAssertTrue(result.needsAssetLoad)
        XCTAssertFalse(result.stoppedPlayback)
        XCTAssertEqual(state.pendingAssetLoadCutIDs, [cutID])
        XCTAssertEqual(
            state.pendingPrefetchRequests,
            [ProjectFramePlaybackPrefetchRequest(cutID: cutID, selectedFrameID: frameIDs[0])]
        )
        XCTAssertEqual(state.workspaces[cutID]?.frameSelection.selectedFrameID, frameIDs[0])
        XCTAssertTrue(state.needsActiveCutRefresh)
    }

    func testAdvanceStopsPlaybackWhenCutIsNoLongerActive() {
        let playbackCutID = makeID(1)
        let activeCutID = makeID(2)
        var state = ProjectFramePlaybackState(
            activeCutID: activeCutID,
            framePlaybackCutID: playbackCutID,
            workspaces: [
                playbackCutID: ProjectFramePlaybackWorkspaceState(
                    frameSelection: makeSelectionState(),
                    isFramePlaybackActive: true
                ),
            ]
        )

        let result = ProjectFramePlaybackCoordinator.advanceFramePlayback(for: playbackCutID, in: &state)

        XCTAssertTrue(result.stoppedPlayback)
        XCTAssertNil(state.framePlaybackCutID)
        XCTAssertEqual(state.workspaces[playbackCutID]?.isFramePlaybackActive, false)
        XCTAssertTrue(state.needsActiveCutRefresh)
    }

    func testCompleteAssetLoadClearsPendingRequestAndRecordsError() {
        let cutID = makeID(1)
        let frameIDs = makeFrameIDs(count: 2)
        var state = ProjectFramePlaybackState(
            activeCutID: cutID,
            workspaces: [
                cutID: ProjectFramePlaybackWorkspaceState(
                    frameSelection: makeSelectionState(frameIDs),
                    frameIDsRequiringAssetLoad: [frameIDs[1]]
                ),
            ],
            pendingAssetLoadCutIDs: [cutID]
        )

        ProjectFramePlaybackCoordinator.completeAssetLoad(
            for: cutID,
            loadedFrameID: frameIDs[1],
            errorMessage: "load failed",
            in: &state
        )

        XCTAssertEqual(state.pendingAssetLoadCutIDs, [UUID]())
        XCTAssertEqual(state.workspaces[cutID]?.frameIDsRequiringAssetLoad, Set<UUID>())
        XCTAssertEqual(state.workspaces[cutID]?.errorMessage, "load failed")
    }

    func testToggleIgnoresMissingActiveWorkspace() {
        var state = ProjectFramePlaybackState(activeCutID: makeID(1))

        let result = ProjectFramePlaybackCoordinator.toggleFramePlayback(in: &state)

        XCTAssertEqual(result, .ignored)
        XCTAssertNil(state.framePlaybackCutID)
        XCTAssertFalse(state.needsActiveCutRefresh)
    }

    private func makeSelectionState(_ frameIDs: [UUID]? = nil) -> CutWorkspaceFrameSelectionState {
        let ids = frameIDs ?? makeFrameIDs(count: 2)
        return CutWorkspaceFrameSelectionState(
            frames: ids.map(CutWorkspaceFrameSelectionFrame.init(id:)),
            selectedFrameID: ids[0],
            selectedFrameIDs: [ids[0]],
            selectedFrameSelectionAnchorID: ids[0],
            lastOpenedFrameID: ids[0]
        )
    }

    private func makeFrameIDs(count: Int) -> [UUID] {
        (0..<count).map { makeID($0 + 10) }
    }

    private func makeID(_ index: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index))!
    }
}
