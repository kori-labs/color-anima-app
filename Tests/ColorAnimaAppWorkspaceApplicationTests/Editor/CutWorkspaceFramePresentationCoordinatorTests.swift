import CoreGraphics
import XCTest
@testable import ColorAnimaAppWorkspaceApplication

final class CutWorkspaceFramePresentationCoordinatorTests: XCTestCase {
    func testPrepareCachesActiveArtworkAndCanvasForResolvedFrame() throws {
        let ids = makeFrameIDs(count: 2)
        let artwork = try makeArtwork(name: "active-outline")
        let regionID = makeID(10)
        var state = makeState(
            ids,
            selectedFrameID: ids[0],
            activeArtwork: CutWorkspaceFrameArtworkState(outline: artwork),
            activeCanvasPresentation: CutWorkspaceCanvasPresentationState(
                selectedRegions: [makeRegion(id: regionID)],
                layerVisibility: LayerVisibility(showHighlightLine: false)
            )
        )

        CutWorkspaceFramePresentationCoordinator.prepareForFramePresentationTransition(in: &state)

        XCTAssertEqual(state.cachedArtworkByFrameID[ids[0]]?.outline?.url.lastPathComponent, "active-outline.png")
        XCTAssertEqual(state.cachedCanvasPresentationByFrameID[ids[0]]?.selectedRegions.map(\.id), [regionID])
        XCTAssertEqual(state.cachedCanvasPresentationByFrameID[ids[0]]?.layerVisibility.showHighlightLine, false)
    }

    func testPrepareDropsOverlayFromCachedCanvasWhenRegionSelectionIsActive() throws {
        let ids = makeFrameIDs(count: 1)
        let regionID = makeID(11)
        let overlayImage = try makeRasterImage()
        var state = makeState(
            ids,
            selectedFrameID: ids[0],
            selectedRegionID: regionID,
            selectedRegionIDs: [regionID],
            selectedRegionAnchorID: regionID,
            activeCanvasPresentation: CutWorkspaceCanvasPresentationState(
                overlayImage: overlayImage
            )
        )

        CutWorkspaceFramePresentationCoordinator.prepareForFramePresentationTransition(in: &state)

        XCTAssertNotNil(state.activeCanvasPresentation.overlayImage)
        XCTAssertNil(state.cachedCanvasPresentationByFrameID[ids[0]]?.overlayImage)
    }

    func testTransitionFrameSelectionCachesPreviousAndRestoresTargetState() throws {
        let ids = makeFrameIDs(count: 2)
        let currentArtwork = try makeArtwork(name: "current")
        let targetArtwork = try makeArtwork(name: "target")
        let regionID = makeID(20)
        var state = makeState(
            ids,
            selectedFrameID: ids[0],
            selectedFrameIDs: [ids[0]],
            selectedFrameSelectionAnchorID: ids[0],
            lastOpenedFrameID: ids[0],
            selectedRegionID: regionID,
            selectedRegionIDs: [regionID],
            selectedRegionAnchorID: regionID,
            activeArtwork: CutWorkspaceFrameArtworkState(outline: currentArtwork),
            cachedArtworkByFrameID: [
                ids[1]: CutWorkspaceFrameArtworkState(outline: targetArtwork),
            ],
            activeCanvasPresentation: CutWorkspaceCanvasPresentationState(
                selectedRegions: [makeRegion(id: regionID)]
            ),
            cachedCanvasPresentationByFrameID: [
                ids[1]: CutWorkspaceCanvasPresentationState(
                    layerVisibility: LayerVisibility(showShadowLine: false)
                ),
            ],
            errorMessage: "stale error"
        )

        let result = CutWorkspaceFramePresentationCoordinator.transitionFrameSelection(to: ids[1], in: &state)

        XCTAssertEqual(
            result,
            CutWorkspaceFramePresentationRestoreResult(
                frameID: ids[1],
                needsArtworkLoad: false,
                restoredCachedCanvas: true
            )
        )
        XCTAssertEqual(state.cachedArtworkByFrameID[ids[0]]?.outline?.url.lastPathComponent, "current.png")
        XCTAssertEqual(state.selectedFrameID, ids[1])
        XCTAssertEqual(state.lastOpenedFrameID, ids[1])
        XCTAssertEqual(state.activeArtwork.outline?.url.lastPathComponent, "target.png")
        XCTAssertEqual(state.activeCanvasPresentation.layerVisibility.showShadowLine, false)
        XCTAssertNil(state.selectedRegionID)
        XCTAssertEqual(state.selectedRegionIDs, [])
        XCTAssertNil(state.selectedRegionAnchorID)
        XCTAssertNil(state.errorMessage)
        XCTAssertTrue(state.needsExtractionStateRefresh)
        XCTAssertFalse(state.needsGuideOverlayRefresh)
    }

    func testRestoreMarksArtworkLoadWhenPersistedAssetHasNoCachedArtwork() {
        let ids = makeFrameIDs(count: 1)
        var state = makeState(
            ids,
            frames: [
                CutWorkspaceFramePresentationFrame(
                    id: ids[0],
                    assetCatalog: CutAssetCatalog(
                        outline: CutAssetRef(kind: .outline, relativePath: "outline.png")
                    )
                ),
            ],
            selectedFrameID: ids[0]
        )

        let result = CutWorkspaceFramePresentationCoordinator.restoreFramePresentationState(for: ids[0], in: &state)

        XCTAssertEqual(result?.needsArtworkLoad, true)
        XCTAssertEqual(result?.restoredCachedCanvas, false)
        XCTAssertFalse(state.needsGuideOverlayRefresh)
        XCTAssertTrue(state.needsExtractionStateRefresh)
    }

    func testRestoreWithoutCachedCanvasRequestsGuideOverlayRefreshWhenArtworkIsReady() throws {
        let ids = makeFrameIDs(count: 1)
        let artwork = try makeArtwork(name: "cached")
        var state = makeState(
            ids,
            frames: [
                CutWorkspaceFramePresentationFrame(
                    id: ids[0],
                    assetCatalog: CutAssetCatalog(
                        outline: CutAssetRef(kind: .outline, relativePath: "outline.png")
                    )
                ),
            ],
            selectedFrameID: ids[0],
            cachedArtworkByFrameID: [
                ids[0]: CutWorkspaceFrameArtworkState(outline: artwork),
            ]
        )

        let result = CutWorkspaceFramePresentationCoordinator.restoreFramePresentationState(for: ids[0], in: &state)

        XCTAssertEqual(result?.needsArtworkLoad, false)
        XCTAssertEqual(result?.restoredCachedCanvas, false)
        XCTAssertTrue(state.needsGuideOverlayRefresh)
        XCTAssertEqual(state.activeArtwork.outline?.url.lastPathComponent, "cached.png")
    }

    func testActivateNewFrameSeedsGuideArtworkButNotCanvasPresentation() throws {
        let ids = makeFrameIDs(count: 2)
        let outlineArtwork = try makeArtwork(name: "seed-outline")
        let highlightArtwork = try makeArtwork(name: "seed-highlight")
        let shadowArtwork = try makeArtwork(name: "seed-shadow")
        let regionID = makeID(30)
        var state = makeState(
            ids,
            selectedFrameID: ids[0],
            selectedFrameIDs: [ids[0]],
            selectedFrameSelectionAnchorID: ids[0],
            lastOpenedFrameID: ids[0],
            activeArtwork: CutWorkspaceFrameArtworkState(
                outline: outlineArtwork,
                highlightLine: highlightArtwork,
                shadowLine: shadowArtwork
            ),
            activeCanvasPresentation: CutWorkspaceCanvasPresentationState(
                selectedRegions: [makeRegion(id: regionID)]
            )
        )

        let result = CutWorkspaceFramePresentationCoordinator.activateNewFrame(ids[1], in: &state)

        XCTAssertEqual(result?.frameID, ids[1])
        XCTAssertEqual(result?.needsArtworkLoad, false)
        XCTAssertEqual(state.selectedFrameID, ids[1])
        XCTAssertEqual(state.selectedFrameIDs, [ids[1]])
        XCTAssertEqual(state.selectedFrameSelectionAnchorID, ids[1])
        XCTAssertEqual(state.lastOpenedFrameID, ids[1])
        XCTAssertEqual(state.cachedArtworkByFrameID[ids[1]]?.outline?.url.lastPathComponent, "seed-outline.png")
        XCTAssertEqual(
            state.cachedArtworkByFrameID[ids[1]]?.highlightLine?.url.lastPathComponent,
            "seed-highlight.png"
        )
        XCTAssertEqual(
            state.cachedArtworkByFrameID[ids[1]]?.shadowLine?.url.lastPathComponent,
            "seed-shadow.png"
        )
        XCTAssertEqual(state.activeArtwork.outline?.url.lastPathComponent, "seed-outline.png")
        XCTAssertEqual(state.activeArtwork.highlightLine?.url.lastPathComponent, "seed-highlight.png")
        XCTAssertEqual(state.activeArtwork.shadowLine?.url.lastPathComponent, "seed-shadow.png")
        XCTAssertEqual(state.cachedCanvasPresentationByFrameID[ids[1]]?.selectedRegions, [])
        XCTAssertEqual(state.activeCanvasPresentation.selectedRegions, [])
    }

    func testResetAndInvalidateCanvasPresentationCaches() throws {
        let ids = makeFrameIDs(count: 3)
        let overlayImage = try makeRasterImage()
        let regionID = makeID(40)
        var state = makeState(
            ids,
            selectedFrameID: ids[0],
            selectedRegionID: regionID,
            selectedRegionIDs: [regionID],
            selectedRegionAnchorID: regionID,
            activeCanvasPresentation: CutWorkspaceCanvasPresentationState(
                overlayImage: overlayImage,
                layerVisibility: LayerVisibility(showShadowLine: false)
            ),
            cachedCanvasPresentationByFrameID: [
                ids[1]: CutWorkspaceCanvasPresentationState(overlayImage: overlayImage),
                ids[2]: CutWorkspaceCanvasPresentationState(overlayImage: overlayImage),
            ],
            errorMessage: "stale"
        )

        CutWorkspaceFramePresentationCoordinator.invalidateCachedCanvasPresentationStates(
            for: [ids[1]],
            in: &state
        )

        XCTAssertNil(state.cachedCanvasPresentationByFrameID[ids[1]])
        XCTAssertNotNil(state.cachedCanvasPresentationByFrameID[ids[2]])

        CutWorkspaceFramePresentationCoordinator.resetFramePresentationState(in: &state)

        XCTAssertNil(state.selectedRegionID)
        XCTAssertEqual(state.selectedRegionIDs, [])
        XCTAssertNil(state.selectedRegionAnchorID)
        XCTAssertTrue(state.cachedCanvasPresentationByFrameID.isEmpty)
        XCTAssertNil(state.activeCanvasPresentation.overlayImage)
        XCTAssertFalse(state.activeCanvasPresentation.layerVisibility.showShadowLine)
        XCTAssertTrue(state.needsGuideOverlayRefresh)
        XCTAssertNil(state.errorMessage)
    }

    func testApplyCanvasPresentationStateFallsBackToFreshState() throws {
        let ids = makeFrameIDs(count: 1)
        let overlayImage = try makeRasterImage()
        var state = makeState(ids)

        CutWorkspaceFramePresentationCoordinator.applyCanvasPresentationState(
            CutWorkspaceCanvasPresentationState(overlayImage: overlayImage),
            in: &state
        )

        XCTAssertNotNil(state.activeCanvasPresentation.overlayImage)

        CutWorkspaceFramePresentationCoordinator.applyCanvasPresentationState(nil, in: &state)

        XCTAssertNil(state.activeCanvasPresentation.overlayImage)
        XCTAssertEqual(state.activeCanvasPresentation.layerVisibility, LayerVisibility())
    }

    func testInvalidFrameSelectionDoesNotMutatePresentation() throws {
        let ids = makeFrameIDs(count: 1)
        let artwork = try makeArtwork(name: "stable")
        var state = makeState(
            ids,
            selectedFrameID: ids[0],
            activeArtwork: CutWorkspaceFrameArtworkState(outline: artwork),
            errorMessage: "keep"
        )

        let result = CutWorkspaceFramePresentationCoordinator.transitionFrameSelection(to: UUID(), in: &state)

        XCTAssertNil(result)
        XCTAssertEqual(state.selectedFrameID, ids[0])
        XCTAssertEqual(state.activeArtwork.outline?.url.lastPathComponent, "stable.png")
        XCTAssertEqual(state.errorMessage, "keep")
    }

    private func makeState(
        _ ids: [UUID],
        frames: [CutWorkspaceFramePresentationFrame]? = nil,
        selectedFrameID: UUID? = nil,
        selectedFrameIDs: Set<UUID> = [],
        selectedFrameSelectionAnchorID: UUID? = nil,
        lastOpenedFrameID: UUID? = nil,
        selectedRegionID: UUID? = nil,
        selectedRegionIDs: Set<UUID> = [],
        selectedRegionAnchorID: UUID? = nil,
        activeArtwork: CutWorkspaceFrameArtworkState = CutWorkspaceFrameArtworkState(),
        cachedArtworkByFrameID: [UUID: CutWorkspaceFrameArtworkState] = [:],
        activeCanvasPresentation: CutWorkspaceCanvasPresentationState = CutWorkspaceCanvasPresentationState(),
        cachedCanvasPresentationByFrameID: [UUID: CutWorkspaceCanvasPresentationState] = [:],
        errorMessage: String? = nil
    ) -> CutWorkspaceFramePresentationState {
        let primary = selectedFrameID ?? ids.first
        return CutWorkspaceFramePresentationState(
            frames: frames ?? ids.map { CutWorkspaceFramePresentationFrame(id: $0) },
            selectedFrameID: primary,
            selectedFrameIDs: selectedFrameIDs.isEmpty ? Set([primary].compactMap { $0 }) : selectedFrameIDs,
            selectedFrameSelectionAnchorID: selectedFrameSelectionAnchorID ?? primary,
            lastOpenedFrameID: lastOpenedFrameID ?? primary,
            selectedRegionID: selectedRegionID,
            selectedRegionIDs: selectedRegionIDs,
            selectedRegionAnchorID: selectedRegionAnchorID,
            activeArtwork: activeArtwork,
            cachedArtworkByFrameID: cachedArtworkByFrameID,
            activeCanvasPresentation: activeCanvasPresentation,
            cachedCanvasPresentationByFrameID: cachedCanvasPresentationByFrameID,
            errorMessage: errorMessage
        )
    }

    private func makeRegion(id: UUID) -> CanvasSelectionRegion {
        CanvasSelectionRegion(
            id: id,
            area: 1,
            boundingBox: CGRect(x: 0, y: 0, width: 1, height: 1),
            pixelIndices: [0]
        )
    }

    private func makeArtwork(name: String) throws -> ImportedArtwork {
        ImportedArtwork(url: URL(fileURLWithPath: "/tmp/\(name).png"), cgImage: try makeCGImage())
    }

    private func makeRasterImage() throws -> CanvasRasterImage {
        let image = try makeCGImage()
        return CanvasRasterImage(cgImage: image, size: CGSize(width: image.width, height: image.height))
    }

    private func makeCGImage() throws -> CGImage {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: 2,
            height: 2,
            bitsPerComponent: 8,
            bytesPerRow: 8,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw TestImageError.failedToCreateContext
        }
        context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
        guard let image = context.makeImage() else {
            throw TestImageError.failedToCreateImage
        }
        return image
    }

    private func makeFrameIDs(count: Int) -> [UUID] {
        (0..<count).map { makeID($0 + 1) }
    }

    private func makeID(_ index: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index))!
    }

    private enum TestImageError: Error {
        case failedToCreateContext
        case failedToCreateImage
    }
}
