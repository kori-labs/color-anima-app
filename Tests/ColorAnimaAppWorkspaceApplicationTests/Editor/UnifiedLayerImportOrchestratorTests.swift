import CoreGraphics
import XCTest
@testable import ColorAnimaAppWorkspaceApplication

@MainActor
final class UnifiedLayerImportOrchestratorTests: XCTestCase {

    // MARK: - importUnifiedLayer

    func testImportUnifiedLayerCancelsWhenFilePromptReturnsNil() async {
        var didCallDecode = false

        let outcome = await UnifiedLayerImportOrchestrator.importUnifiedLayer(
            promptForFile: { nil },
            decodeFrame: { _ in didCallDecode = true; return makeFrameBytes(width: 4, height: 4) },
            splitArtwork: { _ in makeSplitResult(width: 4, height: 4) },
            outlineRef: nil,
            highlightRef: nil,
            shadowRef: nil,
            applyToWorkspace: { _, _, _, _ in UUID() }
        )

        XCTAssertEqual(outcome, .cancelled)
        XCTAssertFalse(didCallDecode)
    }

    func testImportUnifiedLayerReturnsImportedOutcomeWithFrameID() async {
        let expectedFrameID = UUID()
        let testURL = URL(fileURLWithPath: "/tmp/composite.png")
        var decodedURL: URL?
        var splitCalledWithBytes: ImportedFrameBytes?
        var appliedResult: UnifiedLayerSplitResult?

        let outcome = await UnifiedLayerImportOrchestrator.importUnifiedLayer(
            promptForFile: { testURL },
            decodeFrame: { url in
                decodedURL = url
                return makeFrameBytes(width: 4, height: 4)
            },
            splitArtwork: { bytes in
                splitCalledWithBytes = bytes
                return self.makeSplitResult(width: 4, height: 4)
            },
            outlineRef: nil,
            highlightRef: nil,
            shadowRef: nil,
            applyToWorkspace: { result, _, _, _ in
                appliedResult = result
                return expectedFrameID
            }
        )

        XCTAssertEqual(outcome, .imported(outlineFrameID: expectedFrameID))
        XCTAssertEqual(decodedURL, testURL)
        XCTAssertNotNil(splitCalledWithBytes)
        XCTAssertNotNil(appliedResult)
    }

    func testImportUnifiedLayerPassesAssetRefsToApplyCallback() async {
        let outlineRef = CutAssetRef(kind: .outline, relativePath: "frames/001/outline.png")
        let highlightRef = CutAssetRef(kind: .highlightLine, relativePath: "frames/001/highlight.png")
        var receivedOutlineRef: CutAssetRef?
        var receivedHighlightRef: CutAssetRef?
        var receivedShadowRef: CutAssetRef?

        _ = await UnifiedLayerImportOrchestrator.importUnifiedLayer(
            promptForFile: { URL(fileURLWithPath: "/tmp/composite.png") },
            decodeFrame: { _ in self.makeFrameBytes(width: 2, height: 2) },
            splitArtwork: { _ in self.makeSplitResult(width: 2, height: 2) },
            outlineRef: outlineRef,
            highlightRef: highlightRef,
            shadowRef: nil,
            applyToWorkspace: { _, oRef, hRef, sRef in
                receivedOutlineRef = oRef
                receivedHighlightRef = hRef
                receivedShadowRef = sRef
                return UUID()
            }
        )

        XCTAssertEqual(receivedOutlineRef, outlineRef)
        XCTAssertEqual(receivedHighlightRef, highlightRef)
        XCTAssertNil(receivedShadowRef)
    }

    func testImportUnifiedLayerReturnsFailedWhenDecodeThrows() async {
        let outcome = await UnifiedLayerImportOrchestrator.importUnifiedLayer(
            promptForFile: { URL(fileURLWithPath: "/tmp/bad.png") },
            decodeFrame: { _ in throw ImportTestError.decodeFailed },
            splitArtwork: { _ in self.makeSplitResult(width: 4, height: 4) },
            outlineRef: nil,
            highlightRef: nil,
            shadowRef: nil,
            applyToWorkspace: { _, _, _, _ in UUID() }
        )

        guard case let .failed(message) = outcome else {
            XCTFail("Expected failed outcome, got \(outcome)")
            return
        }
        XCTAssertFalse(message.isEmpty)
    }

    func testImportUnifiedLayerReturnsFailedWhenSplitThrows() async {
        let outcome = await UnifiedLayerImportOrchestrator.importUnifiedLayer(
            promptForFile: { URL(fileURLWithPath: "/tmp/composite.png") },
            decodeFrame: { _ in self.makeFrameBytes(width: 4, height: 4) },
            splitArtwork: { _ in throw ImportTestError.splitFailed },
            outlineRef: nil,
            highlightRef: nil,
            shadowRef: nil,
            applyToWorkspace: { _, _, _, _ in UUID() }
        )

        guard case let .failed(message) = outcome else {
            XCTFail("Expected failed outcome, got \(outcome)")
            return
        }
        XCTAssertFalse(message.isEmpty)
    }

    func testImportUnifiedLayerReturnsFailedWhenApplyThrows() async {
        let outcome = await UnifiedLayerImportOrchestrator.importUnifiedLayer(
            promptForFile: { URL(fileURLWithPath: "/tmp/composite.png") },
            decodeFrame: { _ in self.makeFrameBytes(width: 4, height: 4) },
            splitArtwork: { _ in self.makeSplitResult(width: 4, height: 4) },
            outlineRef: nil,
            highlightRef: nil,
            shadowRef: nil,
            applyToWorkspace: { _, _, _, _ in throw ImportTestError.applyFailed }
        )

        guard case let .failed(message) = outcome else {
            XCTFail("Expected failed outcome, got \(outcome)")
            return
        }
        XCTAssertFalse(message.isEmpty)
    }

    // MARK: - loadAndSplitParallel

    func testLoadAndSplitParallelReturnsEmptyForEmptyURLs() async {
        let results = await UnifiedLayerImportOrchestrator.loadAndSplitParallel(
            urls: [],
            decodeFrame: { _ in makeStubFrameBytes(width: 2, height: 2) },
            splitArtwork: { _ in makeStubSplitResult(width: 2, height: 2) }
        )

        XCTAssertTrue(results.isEmpty)
    }

    func testLoadAndSplitParallelReturnsOrderedResultsForMultipleURLs() async {
        let urls = [
            URL(fileURLWithPath: "/tmp/frame-001.png"),
            URL(fileURLWithPath: "/tmp/frame-002.png"),
            URL(fileURLWithPath: "/tmp/frame-003.png"),
        ]

        let results = await UnifiedLayerImportOrchestrator.loadAndSplitParallel(
            urls: urls,
            decodeFrame: { _ in makeStubFrameBytes(width: 2, height: 2) },
            splitArtwork: { _ in makeStubSplitResult(width: 2, height: 2) }
        )

        XCTAssertEqual(results.count, 3)
        let indices = results.compactMap { result -> Int? in
            switch result {
            case let .success(index, _, _): return index
            case .failure: return nil
            }
        }
        XCTAssertEqual(indices, [0, 1, 2])
    }

    func testLoadAndSplitParallelReportsFailurePerURL() async {
        let urls = [
            URL(fileURLWithPath: "/tmp/good.png"),
            URL(fileURLWithPath: "/tmp/bad.png"),
        ]

        let results = await UnifiedLayerImportOrchestrator.loadAndSplitParallel(
            urls: urls,
            decodeFrame: { url in
                if url.lastPathComponent == "bad.png" {
                    throw ImportTestError.decodeFailed
                }
                return makeStubFrameBytes(width: 2, height: 2)
            },
            splitArtwork: { _ in makeStubSplitResult(width: 2, height: 2) }
        )

        XCTAssertEqual(results.count, 2)
        let successCount = results.filter {
            if case .success = $0 { return true }
            return false
        }.count
        let failureCount = results.filter {
            if case .failure = $0 { return true }
            return false
        }.count
        XCTAssertEqual(successCount, 1)
        XCTAssertEqual(failureCount, 1)
    }

    func testLoadAndSplitParallelCallsOnResultForEachURL() async {
        let urls = [
            URL(fileURLWithPath: "/tmp/frame-001.png"),
            URL(fileURLWithPath: "/tmp/frame-002.png"),
        ]
        let counter = StreamCounter()

        _ = await UnifiedLayerImportOrchestrator.loadAndSplitParallel(
            urls: urls,
            decodeFrame: { _ in makeStubFrameBytes(width: 2, height: 2) },
            splitArtwork: { _ in makeStubSplitResult(width: 2, height: 2) },
            onResult: { _ in counter.increment() }
        )

        XCTAssertEqual(counter.value, 2)
    }

    // MARK: - Helpers (MainActor-isolated — used in non-Sendable closure tests only)

    private func makeFrameBytes(width: Int, height: Int) -> ImportedFrameBytes {
        makeStubFrameBytes(width: width, height: height)
    }

    private func makeSplitResult(width: Int, height: Int) -> UnifiedLayerSplitResult {
        makeStubSplitResult(width: width, height: height)
    }

    private enum ImportTestError: LocalizedError {
        case decodeFailed
        case splitFailed
        case applyFailed

        var errorDescription: String? {
            switch self {
            case .decodeFailed: "Decode failed."
            case .splitFailed: "Split failed."
            case .applyFailed: "Apply failed."
            }
        }
    }
}

// MARK: - Sendable-safe free-function helpers (no actor isolation)

private func makeStubFrameBytes(width: Int, height: Int) -> ImportedFrameBytes {
    let bytesPerRow = width * 4
    let bytes = Data(repeating: 0, count: bytesPerRow * height)
    return ImportedFrameBytes(width: width, height: height, bytesPerRow: bytesPerRow, bytes: bytes)
}

private func makeStubSplitResult(width: Int, height: Int) -> UnifiedLayerSplitResult {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let context = CGContext(
        data: nil,
        width: max(width, 1),
        height: max(height, 1),
        bitsPerComponent: 8,
        bytesPerRow: max(width, 1) * 4,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    let cgImage = context.makeImage()!
    let artwork = ImportedArtwork(
        url: URL(fileURLWithPath: "/tmp/outline.png"),
        cgImage: cgImage
    )
    return UnifiedLayerSplitResult(outlineArtwork: artwork)
}

/// Thread-safe counter for streaming result callbacks in tests.
private final class StreamCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var _value = 0

    func increment() {
        lock.lock()
        _value += 1
        lock.unlock()
    }

    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return _value
    }
}
