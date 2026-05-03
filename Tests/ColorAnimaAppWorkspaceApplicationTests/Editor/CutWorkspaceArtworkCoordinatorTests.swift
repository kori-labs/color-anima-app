import CoreGraphics
import XCTest
@testable import ColorAnimaAppWorkspaceApplication

final class CutWorkspaceArtworkCoordinatorTests: XCTestCase {
    func testArtworkReadsActiveAndCachedArtworkByKind() {
        let activeFrameID = UUID()
        let cachedFrameID = UUID()
        let activeOutline = makeArtwork(name: "active-outline.png", width: 4, height: 4)
        let cachedHighlight = makeArtwork(name: "cached-highlight.png", width: 5, height: 5)
        let state = CutWorkspaceArtworkState(
            activeFrameID: activeFrameID,
            activeArtwork: CutWorkspaceFrameArtworkState(outline: activeOutline),
            cachedArtworkByFrameID: [
                cachedFrameID: CutWorkspaceFrameArtworkState(highlightLine: cachedHighlight),
            ]
        )

        XCTAssertEqual(
            CutWorkspaceArtworkCoordinator.artwork(for: .outline, in: state)?.url.lastPathComponent,
            "active-outline.png"
        )
        XCTAssertEqual(
            CutWorkspaceArtworkCoordinator.artwork(
                for: .highlightLine,
                frameID: cachedFrameID,
                in: state
            )?.url.lastPathComponent,
            "cached-highlight.png"
        )
    }

    func testHasCachedArtworkStateAndCacheActiveFrameArtworkState() {
        let frameID = UUID()
        let outline = makeArtwork(name: "outline.png", width: 4, height: 4)
        var state = CutWorkspaceArtworkState(
            activeFrameID: frameID,
            activeArtwork: CutWorkspaceFrameArtworkState(outline: outline)
        )

        XCTAssertFalse(CutWorkspaceArtworkCoordinator.hasCachedArtworkState(for: frameID, in: state))

        CutWorkspaceArtworkCoordinator.cacheActiveFrameArtworkState(in: &state)

        XCTAssertTrue(CutWorkspaceArtworkCoordinator.hasCachedArtworkState(for: frameID, in: state))
        XCTAssertEqual(
            state.cachedArtworkByFrameID[frameID]?.outline?.url.lastPathComponent,
            "outline.png"
        )
    }

    func testApplyAndResetArtworkState() {
        let frameID = UUID()
        let highlight = makeArtwork(name: "highlight.png", width: 4, height: 4)
        let cached = makeArtwork(name: "cached.png", width: 5, height: 5)
        var state = CutWorkspaceArtworkState(
            activeFrameID: frameID,
            cachedArtworkByFrameID: [
                frameID: CutWorkspaceFrameArtworkState(outline: cached),
            ]
        )

        CutWorkspaceArtworkCoordinator.applyArtworkState(
            CutWorkspaceFrameArtworkState(highlightLine: highlight),
            in: &state
        )

        XCTAssertEqual(state.activeArtwork.highlightLine?.url.lastPathComponent, "highlight.png")
        XCTAssertNil(state.activeArtwork.outline)

        CutWorkspaceArtworkCoordinator.resetArtworkState(in: &state)

        XCTAssertNil(state.activeArtwork.highlightLine)
        XCTAssertTrue(state.cachedArtworkByFrameID.isEmpty)
        XCTAssertTrue(state.needsGuideFillMapRecompute)
    }

    func testApplyLoadedArtworkUpdatesActiveCacheAndRecomputeFlag() {
        let frameID = UUID()
        let artwork = makeArtwork(name: "outline.png", width: 6, height: 6)
        var state = CutWorkspaceArtworkState(activeFrameID: frameID)

        CutWorkspaceArtworkCoordinator.applyLoadedArtwork(
            artwork,
            for: .outline,
            in: &state
        )

        XCTAssertEqual(state.activeArtwork.outline?.url.lastPathComponent, "outline.png")
        XCTAssertEqual(
            state.cachedArtworkByFrameID[frameID]?.outline?.url.lastPathComponent,
            "outline.png"
        )
        XCTAssertTrue(state.needsGuideFillMapRecompute)
    }

    func testImportArtworkStoresAssetRefAndMarksWorkspaceEffects() {
        let frameID = UUID()
        let artwork = makeArtwork(name: "shadow.png", width: 8, height: 8)
        let assetRef = CutAssetRef(
            kind: .shadowLine,
            relativePath: "frames/001/shadow.png",
            originalFilename: "shadow.png"
        )
        var state = CutWorkspaceArtworkState(
            activeFrameID: frameID,
            isDirty: false,
            errorMessage: "previous error"
        )

        CutWorkspaceArtworkCoordinator.importArtwork(
            artwork,
            assetRef: assetRef,
            kind: .shadowLine,
            in: &state
        )

        XCTAssertEqual(state.activeArtwork.shadowLine?.url.lastPathComponent, "shadow.png")
        XCTAssertEqual(state.assetCatalogByFrameID[frameID]?.shadowLine, assetRef)
        XCTAssertTrue(state.needsRegionExtractionReset)
        XCTAssertTrue(state.needsPreviewRefresh)
        XCTAssertTrue(state.isDirty)
        XCTAssertNil(state.errorMessage)
    }

    func testRebindPersistedArtworkURLsKeepsSelectionAndRewritesActiveAndCachedURLs() {
        let activeFrameID = UUID()
        let cachedFrameID = UUID()
        let cutFolderURL = URL(fileURLWithPath: "/tmp/color-anima-cut", isDirectory: true)
        let activeArtwork = makeArtwork(name: "old-active.png", width: 3, height: 3)
        let cachedArtwork = makeArtwork(name: "old-cached.png", width: 7, height: 7)
        let activeAsset = CutAssetRef(kind: .outline, relativePath: "active/outline.png")
        let cachedAsset = CutAssetRef(kind: .highlightLine, relativePath: "cached/highlight.png")
        var state = CutWorkspaceArtworkState(
            activeFrameID: activeFrameID,
            fallbackFrameID: UUID(),
            activeArtwork: CutWorkspaceFrameArtworkState(outline: activeArtwork),
            cachedArtworkByFrameID: [
                cachedFrameID: CutWorkspaceFrameArtworkState(highlightLine: cachedArtwork),
            ]
        )

        CutWorkspaceArtworkCoordinator.rebindPersistedArtworkURLs(
            frames: [
                CutWorkspaceArtworkFrameRecord(
                    id: activeFrameID,
                    assetCatalog: CutAssetCatalog(outline: activeAsset)
                ),
                CutWorkspaceArtworkFrameRecord(
                    id: cachedFrameID,
                    assetCatalog: CutAssetCatalog(highlightLine: cachedAsset)
                ),
            ],
            cutFolderURL: cutFolderURL,
            in: &state
        )

        XCTAssertEqual(state.activeFrameID, activeFrameID)
        XCTAssertEqual(
            state.activeArtwork.outline?.url.standardizedFileURL.path,
            cutFolderURL.appendingPathComponent(activeAsset.relativePath).standardizedFileURL.path
        )
        XCTAssertEqual(
            state.cachedArtworkByFrameID[cachedFrameID]?.highlightLine?.url.standardizedFileURL.path,
            cutFolderURL.appendingPathComponent(cachedAsset.relativePath).standardizedFileURL.path
        )
        XCTAssertEqual(state.activeArtwork.outline?.size, activeArtwork.size)
        XCTAssertEqual(state.cachedArtworkByFrameID[cachedFrameID]?.highlightLine?.size, cachedArtwork.size)
    }

    func testRebindSkipsMissingArtworkButStoresFrameCatalog() {
        let frameID = UUID()
        let assetRef = CutAssetRef(kind: .outline, relativePath: "outline.png")
        var state = CutWorkspaceArtworkState(activeFrameID: frameID)

        CutWorkspaceArtworkCoordinator.rebindPersistedArtworkURLs(
            frames: [
                CutWorkspaceArtworkFrameRecord(
                    id: frameID,
                    assetCatalog: CutAssetCatalog(outline: assetRef)
                ),
            ],
            cutFolderURL: URL(fileURLWithPath: "/tmp/cut", isDirectory: true),
            in: &state
        )

        XCTAssertNil(state.activeArtwork.outline)
        XCTAssertEqual(state.assetCatalogByFrameID[frameID]?.outline, assetRef)
    }

    private func makeArtwork(name: String, width: Int, height: Int) -> ImportedArtwork {
        ImportedArtwork(
            url: URL(fileURLWithPath: "/tmp/\(name)", isDirectory: false),
            cgImage: makeImage(width: width, height: height)
        )
    }

    private func makeImage(width: Int, height: Int) -> CGImage {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        pixels.indices.filter { $0 % 4 == 3 }.forEach { pixels[$0] = 255 }
        let provider = CGDataProvider(data: Data(pixels) as CFData)!
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )!
    }
}
