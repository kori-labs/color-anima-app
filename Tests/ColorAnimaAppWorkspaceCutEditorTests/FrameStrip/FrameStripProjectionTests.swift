import XCTest
@testable import ColorAnimaAppWorkspaceCutEditor

final class FrameStripProjectionTests: XCTestCase {
    func testFrameStripProjectionMapsTrackingSummariesToBadges() throws {
        let referenceFrameID = makeID(1)
        let trackedFrameID = makeID(2)
        let moderateTrackedFrameID = makeID(3)
        let reviewFrameID = makeID(4)
        let unresolvedFrameID = makeID(5)
        let notRunFrameID = makeID(6)

        let itemsByID = Dictionary(uniqueKeysWithValues: FrameStripProjection.cardItems(from: [
            makeFrame(id: referenceFrameID, orderIndex: 0, isIncludedReference: true, isActiveReference: true),
            makeFrame(id: trackedFrameID, orderIndex: 1, trackingState: .tracked, trackingConfidence: 0.91),
            makeFrame(id: moderateTrackedFrameID, orderIndex: 2, trackingState: .tracked, trackingConfidence: 0.78),
            makeFrame(id: reviewFrameID, orderIndex: 3, trackingState: .reviewNeeded, trackingConfidence: 0.63),
            makeFrame(id: unresolvedFrameID, orderIndex: 4, trackingState: .unresolved, trackingConfidence: 0.18),
            makeFrame(id: notRunFrameID, orderIndex: 5, trackingState: .needsExtraction),
        ]).map { ($0.id, $0) })

        XCTAssertEqual(
            itemsByID[referenceFrameID]?.trackingBadge,
            FrameStripTrackingBadge(state: .reference, label: "Ref", tint: .green)
        )
        XCTAssertEqual(
            itemsByID[trackedFrameID]?.trackingBadge,
            FrameStripTrackingBadge(state: .tracked, confidencePercent: 91, tint: .green)
        )
        XCTAssertEqual(
            itemsByID[moderateTrackedFrameID]?.trackingBadge,
            FrameStripTrackingBadge(state: .tracked, confidencePercent: 78, tint: .neutral)
        )
        XCTAssertEqual(
            itemsByID[reviewFrameID]?.trackingBadge,
            FrameStripTrackingBadge(state: .reviewNeeded, confidencePercent: 63, tint: .orange)
        )
        XCTAssertEqual(
            itemsByID[unresolvedFrameID]?.trackingBadge,
            FrameStripTrackingBadge(state: .unresolved, tint: .red)
        )
        XCTAssertEqual(
            itemsByID[notRunFrameID]?.trackingBadge,
            FrameStripTrackingBadge(state: .needsExtraction, tint: .gray)
        )
        XCTAssertFalse(itemsByID[referenceFrameID]?.showsPersistentReferenceAction ?? true)
        XCTAssertFalse(itemsByID[notRunFrameID]?.showsPersistentReferenceAction ?? true)
    }

    func testFrameStripProjectionShowsPersistentReferenceActionOnlyForExtractedNonReferenceFrames() {
        let referenceFrameID = makeID(1)
        let extractedFrameID = makeID(2)
        let unextractedFrameID = makeID(3)

        let itemsByID = Dictionary(uniqueKeysWithValues: FrameStripProjection.cardItems(from: [
            makeFrame(id: referenceFrameID, orderIndex: 0, isIncludedReference: true, hasExtractedRegions: true),
            makeFrame(id: extractedFrameID, orderIndex: 1, hasExtractedRegions: true),
            makeFrame(id: unextractedFrameID, orderIndex: 2, hasExtractedRegions: false),
        ]).map { ($0.id, $0) })

        XCTAssertFalse(itemsByID[referenceFrameID]?.showsPersistentReferenceAction ?? true)
        XCTAssertTrue(itemsByID[extractedFrameID]?.showsPersistentReferenceAction ?? false)
        XCTAssertFalse(itemsByID[unextractedFrameID]?.showsPersistentReferenceAction ?? true)
    }

    func testFrameStripBadgeRegressionSnapshotIsStable() {
        let snapshot = FrameStripProjection.cardItems(from: [
            makeFrame(id: makeID(1), orderIndex: 0, isIncludedReference: true, isActiveReference: true),
            makeFrame(id: makeID(2), orderIndex: 1, trackingState: .tracked, trackingConfidence: 0.91),
            makeFrame(id: makeID(3), orderIndex: 2, trackingState: .tracked, trackingConfidence: 0.78),
            makeFrame(id: makeID(4), orderIndex: 3, trackingState: .reviewNeeded, trackingConfidence: 0.63),
            makeFrame(id: makeID(5), orderIndex: 4, trackingState: .unresolved, trackingConfidence: 0.18),
            makeFrame(id: makeID(6), orderIndex: 5, trackingState: .needsExtraction),
        ])
        .map { "\($0.frameLabel)=\(badgeSnapshot($0.trackingBadge))" }

        XCTAssertEqual(snapshot, [
            "#001=reference|Ref|green",
            "#002=tracked|91%|green",
            "#003=tracked|78%|neutral",
            "#004=reviewNeeded|63% ⚠|orange",
            "#005=unresolved|— ?|red",
            "#006=needsExtraction|Extract|gray",
        ])
    }

    func testFrameStripProjectionMapsExplicitReferenceStateToReferenceBadge() throws {
        let frameID = makeID(7)

        let item = try XCTUnwrap(FrameStripProjection.cardItems(from: [
            makeFrame(id: frameID, orderIndex: 0, trackingState: .reference),
        ]).first)

        XCTAssertEqual(
            item.trackingBadge,
            FrameStripTrackingBadge(state: .reference, label: "Ref", tint: .green)
        )
    }

    func testFrameStripProjectionReturnsNeedsExtractionBadgeForFrameWithNoRegions() throws {
        let item = try XCTUnwrap(FrameStripProjection.cardItems(from: [
            makeFrame(id: makeID(8), orderIndex: 0, hasExtractedRegions: false),
        ]).first)

        XCTAssertEqual(item.trackingBadge?.state, .needsExtraction)
        XCTAssertEqual(item.trackingBadge?.label, "Extract")
    }

    func testFrameStripProjectionIsDeterministicForSameWorkspaceState() {
        let frames = [
            makeFrame(id: makeID(9), orderIndex: 0, trackingState: .tracked, trackingConfidence: 0.9),
            makeFrame(id: makeID(10), orderIndex: 1, hasExtractedRegions: true),
        ]

        XCTAssertEqual(FrameStripProjection.cardItems(from: frames), FrameStripProjection.cardItems(from: frames))
    }

    func testFrameStripProjectionReflectsCurrentFrameChanges() {
        let firstFrameID = makeID(11)
        let secondFrameID = makeID(12)

        let initialItems = FrameStripProjection.cardItems(from: [
            makeFrame(id: firstFrameID, orderIndex: 0, isCurrent: false),
            makeFrame(id: secondFrameID, orderIndex: 1, isCurrent: true),
        ])
        XCTAssertTrue(initialItems.contains(where: { $0.id == secondFrameID && $0.isCurrent }))
        XCTAssertFalse(initialItems.contains(where: { $0.id == firstFrameID && $0.isCurrent }))

        let updatedItems = FrameStripProjection.cardItems(from: [
            makeFrame(id: firstFrameID, orderIndex: 0, isCurrent: true),
            makeFrame(id: secondFrameID, orderIndex: 1, isCurrent: false),
        ])
        XCTAssertTrue(updatedItems.contains(where: { $0.id == firstFrameID && $0.isCurrent }))
        XCTAssertFalse(updatedItems.contains(where: { $0.id == secondFrameID && $0.isCurrent }))
    }

    func testFrameStripProjectionReflectsReferenceMembershipChanges() throws {
        let frameID = makeID(13)

        let initialItem = try XCTUnwrap(FrameStripProjection.cardItems(from: [
            makeFrame(id: frameID, orderIndex: 0, isIncludedReference: false),
        ]).first)
        XCTAssertNotEqual(initialItem.trackingBadge?.state, .reference)

        let updatedItem = try XCTUnwrap(FrameStripProjection.cardItems(from: [
            makeFrame(id: frameID, orderIndex: 0, isIncludedReference: true),
        ]).first)
        XCTAssertEqual(
            updatedItem.trackingBadge,
            FrameStripTrackingBadge(state: .reference, label: "Ref", tint: .green)
        )
    }

    func testFrameStripProjectionUsesDisplayFilenameAndPlaceholderState() throws {
        let itemWithFilename = try XCTUnwrap(FrameStripProjection.cardItems(from: [
            makeFrame(id: makeID(14), orderIndex: 0, displayFilename: "outline.png"),
        ]).first)
        let placeholderItem = try XCTUnwrap(FrameStripProjection.cardItems(from: [
            makeFrame(id: makeID(15), orderIndex: 0, displayFilename: " "),
        ]).first)

        XCTAssertEqual(itemWithFilename.displayFilename, "outline.png")
        XCTAssertFalse(itemWithFilename.isDisplayFilenamePlaceholder)
        XCTAssertEqual(placeholderItem.displayFilename, "No artwork")
        XCTAssertTrue(placeholderItem.isDisplayFilenamePlaceholder)
    }

    private func makeFrame(
        id: UUID,
        orderIndex: Int,
        frameLabel: String? = nil,
        displayFilename: String? = nil,
        isCurrent: Bool = false,
        isSelected: Bool = false,
        isIncludedReference: Bool = false,
        isActiveReference: Bool = false,
        hasExtractedRegions: Bool = false,
        trackingState: FrameStripTrackingBadgeState? = nil,
        trackingConfidence: Double? = nil
    ) -> FrameStripProjectionInput {
        FrameStripProjectionInput(
            id: id,
            orderIndex: orderIndex,
            frameLabel: frameLabel,
            displayFilename: displayFilename,
            isCurrent: isCurrent,
            isSelected: isSelected,
            isIncludedReference: isIncludedReference,
            isActiveReference: isActiveReference,
            hasExtractedRegions: hasExtractedRegions,
            trackingState: trackingState,
            trackingConfidence: trackingConfidence
        )
    }

    private func badgeSnapshot(_ badge: FrameStripTrackingBadge?) -> String {
        guard let badge else { return "none" }
        return "\(badge.state.rawValue)|\(badge.label)|\(badge.tint.rawValue)"
    }

    private func makeID(_ index: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index))!
    }
}
