import ColorAnimaAppWorkspaceApplication
import XCTest

final class CutWorkspaceTrackingReadinessTests: XCTestCase {
    func testReadinessBlocksWhenTrackingTaskIsActive() {
        let frames = makeFrames(count: 2, extracted: true)

        let readiness = CutWorkspaceTrackingReadiness.readiness(
            frames: frames,
            keyFrameIDs: [frames[0].id],
            isTrackingTaskActive: true
        )

        XCTAssertEqual(
            readiness,
            TrackingRunReadiness(canRun: false, reason: "A tracking task is already in progress.")
        )
    }

    func testReadinessRequiresAtLeastTwoFrames() {
        let frames = makeFrames(count: 1, extracted: true)

        let readiness = CutWorkspaceTrackingReadiness.readiness(
            frames: frames,
            keyFrameIDs: [frames[0].id]
        )

        XCTAssertEqual(
            readiness,
            TrackingRunReadiness(canRun: false, reason: "Tracking needs at least 2 frames.")
        )
    }

    func testReadinessRequiresReferenceFrame() {
        let frames = makeFrames(count: 2, extracted: true)

        let readiness = CutWorkspaceTrackingReadiness.readiness(
            frames: frames,
            keyFrameIDs: []
        )

        XCTAssertEqual(
            readiness,
            TrackingRunReadiness(canRun: false, reason: "Add a reference frame before running tracking.")
        )
    }

    func testReadinessRequiresExtractedRegionsForEveryFrame() {
        let frames = makeFrames(count: 2, extracted: false)

        let readiness = CutWorkspaceTrackingReadiness.readiness(
            frames: frames,
            keyFrameIDs: [frames[0].id]
        )

        XCTAssertEqual(
            readiness,
            TrackingRunReadiness(canRun: false, reason: "Extract regions for every frame before running tracking.")
        )
    }

    func testReadinessRequiresAtLeastOneTargetFrame() {
        let frames = makeFrames(count: 2, extracted: true)

        let readiness = CutWorkspaceTrackingReadiness.readiness(
            frames: frames,
            keyFrameIDs: frames.map(\.id)
        )

        XCTAssertEqual(
            readiness,
            TrackingRunReadiness(canRun: false, reason: "At least one non-reference frame is required for tracking.")
        )
    }

    func testReadinessAllowsRunWhenRequiredInputsExist() {
        let frames = makeFrames(count: 3, extracted: true)

        let readiness = CutWorkspaceTrackingReadiness.readiness(
            frames: frames,
            keyFrameIDs: [frames[0].id]
        )

        XCTAssertEqual(readiness, TrackingRunReadiness(canRun: true))
    }

    func testDemoteReferenceFrameIDsKeepsOnlyAssignedReferenceFrames() {
        let preferred = UUID()
        let unassigned = UUID()
        let frames = [
            CutWorkspaceTrackingReadinessFrame(
                id: preferred,
                hasExtractedRegions: true,
                hasAssignedRegions: true
            ),
            CutWorkspaceTrackingReadinessFrame(
                id: unassigned,
                hasExtractedRegions: true,
                hasAssignedRegions: false
            ),
        ]

        let selection = CutWorkspaceTrackingReadiness.demoteReferenceFrameIDs(
            referenceIDs: [preferred, unassigned],
            preferredID: preferred,
            frames: frames
        )

        XCTAssertEqual(selection.effectiveReferenceFrameIDs, [preferred])
        XCTAssertEqual(selection.effectivePreferredReferenceFrameID, preferred)
    }

    func testDemoteReferenceFrameIDsClearsPreferredWhenItIsDemoted() {
        let assigned = UUID()
        let preferred = UUID()
        let frames = [
            CutWorkspaceTrackingReadinessFrame(
                id: assigned,
                hasExtractedRegions: true,
                hasAssignedRegions: true
            ),
            CutWorkspaceTrackingReadinessFrame(
                id: preferred,
                hasExtractedRegions: true,
                hasAssignedRegions: false
            ),
        ]

        let selection = CutWorkspaceTrackingReadiness.demoteReferenceFrameIDs(
            referenceIDs: [assigned, preferred],
            preferredID: preferred,
            frames: frames
        )

        XCTAssertEqual(selection.effectiveReferenceFrameIDs, [assigned])
        XCTAssertNil(selection.effectivePreferredReferenceFrameID)
    }

    private func makeFrames(count: Int, extracted: Bool) -> [CutWorkspaceTrackingReadinessFrame] {
        (0..<count).map { _ in
            CutWorkspaceTrackingReadinessFrame(
                id: UUID(),
                hasExtractedRegions: extracted,
                hasAssignedRegions: extracted
            )
        }
    }
}
