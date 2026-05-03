import ColorAnimaAppWorkspaceApplication
import XCTest

final class CutWorkspaceConfidenceProjectionTests: XCTestCase {
    func testFrameRowsReturnsEmptyWhenNoFramesExist() {
        let rows = CutWorkspaceConfidenceProjection.frameRows(from: [])

        XCTAssertTrue(rows.isEmpty)
    }

    func testFrameRowsExcludesFramesWithNoRegionResults() {
        let frame = FrameConfidenceProjectionInput(
            frameID: UUID(),
            orderIndex: 0,
            regions: []
        )

        let rows = CutWorkspaceConfidenceProjection.frameRows(from: [frame])

        XCTAssertTrue(rows.isEmpty)
    }

    func testFrameRowsReturnsRowForTrackedFrame() throws {
        let frameID = UUID()
        let regionID = UUID()
        let frame = makeFrame(
            frameID: frameID,
            regions: [
                makeRegion(
                    regionID: regionID,
                    reviewState: .tracked,
                    confidenceValue: 0.9
                )
            ]
        )

        let row = try XCTUnwrap(CutWorkspaceConfidenceProjection.frameRows(from: [frame]).first)

        XCTAssertEqual(row.frameID, frameID)
        XCTAssertEqual(row.frameLabel, "#001")
        XCTAssertEqual(row.reviewState, .tracked)
        XCTAssertEqual(row.averageConfidence, 0.9, accuracy: 0.001)
        XCTAssertEqual(row.regionResults.first?.regionID, regionID)
    }

    func testFrameRowsUsesProvidedFrameLabelWhenAvailable() throws {
        let frame = makeFrame(
            frameLabel: "Shot A",
            orderIndex: 9,
            regions: [makeRegion(reviewState: .tracked, confidenceValue: 0.8)]
        )

        let row = try XCTUnwrap(CutWorkspaceConfidenceProjection.frameRows(from: [frame]).first)

        XCTAssertEqual(row.frameLabel, "Shot A")
        XCTAssertEqual(row.orderIndex, 9)
    }

    func testWorstStateIsUnresolvedWhenAnyRegionIsUnresolved() throws {
        let frame = makeFrame(
            regions: [
                makeRegion(reviewState: .tracked, confidenceValue: 0.9),
                makeRegion(reviewState: .unresolved, confidenceValue: 0.1)
            ]
        )

        let row = try XCTUnwrap(CutWorkspaceConfidenceProjection.frameRows(from: [frame]).first)

        XCTAssertEqual(row.reviewState, .unresolved)
    }

    func testWorstStateIsReviewNeededWhenNoUnresolvedRegionExists() throws {
        let frame = makeFrame(
            regions: [
                makeRegion(reviewState: .tracked, confidenceValue: 0.9),
                makeRegion(reviewState: .reviewNeeded, confidenceValue: 0.55)
            ]
        )

        let row = try XCTUnwrap(CutWorkspaceConfidenceProjection.frameRows(from: [frame]).first)

        XCTAssertEqual(row.reviewState, .reviewNeeded)
    }

    func testFrameRowsAverageConfidenceAcrossRegions() throws {
        let frame = makeFrame(
            regions: [
                makeRegion(reviewState: .tracked, confidenceValue: 0.8),
                makeRegion(reviewState: .reviewNeeded, confidenceValue: 0.4)
            ]
        )

        let row = try XCTUnwrap(CutWorkspaceConfidenceProjection.frameRows(from: [frame]).first)

        XCTAssertEqual(row.averageConfidence, 0.6, accuracy: 0.001)
    }

    func testMissingConfidenceCountsAsZeroForAverageAndRegionRows() throws {
        let missingConfidenceID = UUID(uuidString: "00000000-0000-4000-8000-000000000001")!
        let presentConfidenceID = UUID(uuidString: "00000000-0000-4000-8000-000000000002")!
        let frame = makeFrame(
            regions: [
                makeRegion(
                    regionID: presentConfidenceID,
                    reviewState: .tracked,
                    confidenceValue: 0.8
                ),
                makeRegion(
                    regionID: missingConfidenceID,
                    reviewState: .tracked,
                    confidenceValue: nil
                )
            ]
        )

        let row = try XCTUnwrap(CutWorkspaceConfidenceProjection.frameRows(from: [frame]).first)

        XCTAssertEqual(row.averageConfidence, 0.4, accuracy: 0.001)
        XCTAssertEqual(row.regionResults.first?.confidenceValue, 0)
    }

    func testFilterAllReturnsAllRows() {
        let frames = makeThreeFrames()

        let rows = CutWorkspaceConfidenceProjection.filteredFrameRows(from: frames, filter: .all)

        XCTAssertEqual(rows.count, 3)
    }

    func testFilterReviewNeededReturnsOnlyReviewNeededFrames() {
        let frames = makeThreeFrames()

        let rows = CutWorkspaceConfidenceProjection.filteredFrameRows(
            from: frames,
            filter: .reviewNeeded
        )

        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].reviewState, .reviewNeeded)
    }

    func testFilterUnresolvedReturnsOnlyUnresolvedFrames() {
        let frames = makeThreeFrames()

        let rows = CutWorkspaceConfidenceProjection.filteredFrameRows(
            from: frames,
            filter: .unresolved
        )

        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].reviewState, .unresolved)
    }

    func testRegionRowsCarryReasonCodesAndStableRegionOrdering() throws {
        let lowID = UUID(uuidString: "00000000-0000-4000-8000-000000000001")!
        let highID = UUID(uuidString: "00000000-0000-4000-8000-000000000002")!
        let frame = makeFrame(
            regions: [
                makeRegion(
                    regionID: highID,
                    reviewState: .tracked,
                    confidenceValue: 0.8,
                    reasonCodes: [.lowMargin]
                ),
                makeRegion(
                    regionID: lowID,
                    reviewState: .reviewNeeded,
                    confidenceValue: 0.55,
                    reasonCodes: [.lowMargin, .insufficientSupport]
                )
            ]
        )

        let row = try XCTUnwrap(CutWorkspaceConfidenceProjection.frameRows(from: [frame]).first)

        XCTAssertEqual(row.regionResults.map(\.regionID), [lowID, highID])
        XCTAssertEqual(row.regionResults[0].reasonCodes, [.lowMargin, .insufficientSupport])
        XCTAssertEqual(row.regionResults[1].reasonCodes, [.lowMargin])
    }

    func testEmptyRegionDisplayNameFallsBackToGenericName() throws {
        let frame = makeFrame(
            regions: [
                makeRegion(
                    regionDisplayName: "",
                    reviewState: .tracked,
                    confidenceValue: 0.8
                )
            ]
        )

        let row = try XCTUnwrap(CutWorkspaceConfidenceProjection.frameRows(from: [frame]).first)

        XCTAssertEqual(row.regionResults.first?.regionDisplayName, "Region")
    }

    private func makeThreeFrames() -> [FrameConfidenceProjectionInput] {
        [
            makeFrame(orderIndex: 0, regions: [
                makeRegion(reviewState: .tracked, confidenceValue: 0.9)
            ]),
            makeFrame(orderIndex: 1, regions: [
                makeRegion(reviewState: .reviewNeeded, confidenceValue: 0.55)
            ]),
            makeFrame(orderIndex: 2, regions: [
                makeRegion(reviewState: .unresolved, confidenceValue: 0.1)
            ])
        ]
    }

    private func makeFrame(
        frameID: UUID = UUID(),
        frameLabel: String? = nil,
        orderIndex: Int = 0,
        regions: [RegionConfidenceProjectionInput]
    ) -> FrameConfidenceProjectionInput {
        FrameConfidenceProjectionInput(
            frameID: frameID,
            frameLabel: frameLabel,
            orderIndex: orderIndex,
            regions: regions
        )
    }

    private func makeRegion(
        regionID: UUID = UUID(),
        regionDisplayName: String = "Region",
        reviewState: ConfidenceReviewState,
        confidenceValue: Double?,
        reasonCodes: [TrackingReviewReasonCode] = []
    ) -> RegionConfidenceProjectionInput {
        RegionConfidenceProjectionInput(
            regionID: regionID,
            regionDisplayName: regionDisplayName,
            confidenceValue: confidenceValue,
            reviewState: reviewState,
            reasonCodes: reasonCodes
        )
    }
}
