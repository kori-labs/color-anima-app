import CoreGraphics
import XCTest
@testable import ColorAnimaAppWorkspaceApplication

@MainActor
final class ExportOrchestratorTests: XCTestCase {

    // MARK: - exportFrame

    func testExportFrameFailsWhenOutlineArtworkIsMissing() async {
        let outcome = await ExportOrchestrator.exportFrame(
            definition: .visiblePreview,
            outlineArtwork: nil,
            compositeImage: makeImage(width: 4, height: 4),
            resolveSaveTarget: { URL(fileURLWithPath: "/tmp/out.png") },
            encodeAndWrite: { _, _ in }
        )

        XCTAssertEqual(outcome, .failed(message: "Import an outline image before exporting."))
    }

    func testExportFrameFailsWhenCompositeImageIsNil() async {
        let artwork = makeArtwork(name: "outline.png", width: 4, height: 4)

        let outcome = await ExportOrchestrator.exportFrame(
            definition: .visiblePreview,
            outlineArtwork: artwork,
            compositeImage: nil,
            resolveSaveTarget: { URL(fileURLWithPath: "/tmp/out.png") },
            encodeAndWrite: { _, _ in }
        )

        XCTAssertEqual(outcome, .failed(message: "Nothing to export yet."))
    }

    func testExportFrameCancelsWhenResolveSaveTargetReturnsNil() async {
        let artwork = makeArtwork(name: "outline.png", width: 4, height: 4)
        var didCallEncode = false

        let outcome = await ExportOrchestrator.exportFrame(
            definition: .visiblePreview,
            outlineArtwork: artwork,
            compositeImage: makeImage(width: 4, height: 4),
            resolveSaveTarget: { nil },
            encodeAndWrite: { _, _ in didCallEncode = true }
        )

        XCTAssertEqual(outcome, .cancelled)
        XCTAssertFalse(didCallEncode)
    }

    func testExportFrameReturnsExportedURLOnSuccess() async throws {
        let artwork = makeArtwork(name: "outline.png", width: 4, height: 4)
        let targetURL = URL(fileURLWithPath: "/tmp/export-test.png")
        var encodedURL: URL?

        let outcome = await ExportOrchestrator.exportFrame(
            definition: .visiblePreview,
            outlineArtwork: artwork,
            compositeImage: makeImage(width: 4, height: 4),
            resolveSaveTarget: { targetURL },
            encodeAndWrite: { _, url in encodedURL = url }
        )

        XCTAssertEqual(outcome, .exported(url: targetURL))
        XCTAssertEqual(encodedURL, targetURL)
    }

    func testExportFrameReturnsFailedWhenEncoderThrows() async {
        let artwork = makeArtwork(name: "outline.png", width: 4, height: 4)

        let outcome = await ExportOrchestrator.exportFrame(
            definition: .visiblePreview,
            outlineArtwork: artwork,
            compositeImage: makeImage(width: 4, height: 4),
            resolveSaveTarget: { URL(fileURLWithPath: "/tmp/out.png") },
            encodeAndWrite: { _, _ in throw ExportTestError.encoderFailed }
        )

        guard case let .failed(message) = outcome else {
            XCTFail("Expected failed outcome, got \(outcome)")
            return
        }
        XCTAssertFalse(message.isEmpty)
    }

    // MARK: - exportPNGSequence

    func testExportPNGSequenceFailsWhenSnapshotsIsEmpty() async {
        let outcome = await ExportOrchestrator.exportPNGSequence(
            snapshots: [],
            resolveExportDirectory: { URL(fileURLWithPath: "/tmp/export") },
            encodeFrame: { _, _ in }
        )

        XCTAssertEqual(outcome, .failed(message: "No frames available to export."))
    }

    func testExportPNGSequenceCancelsWhenDirectoryPickerReturnsNil() async {
        let snapshot = ExportFrameSnapshot(
            frameID: UUID(),
            orderIndex: 0,
            compositeImage: makeImage(width: 2, height: 2)
        )
        var didCallEncodeFrame = false

        let outcome = await ExportOrchestrator.exportPNGSequence(
            snapshots: [snapshot],
            resolveExportDirectory: { nil },
            encodeFrame: { _, _ in didCallEncodeFrame = true }
        )

        XCTAssertEqual(outcome, .cancelled)
        XCTAssertFalse(didCallEncodeFrame)
    }

    func testExportPNGSequenceReturnsExportedOutcomeWithFrameCount() async {
        let dirURL = URL(fileURLWithPath: "/tmp/export-seq")
        let snapshots = [
            ExportFrameSnapshot(frameID: UUID(), orderIndex: 0, compositeImage: makeImage(width: 2, height: 2)),
            ExportFrameSnapshot(frameID: UUID(), orderIndex: 1, compositeImage: makeImage(width: 2, height: 2)),
        ]
        var encodedIndices: [Int] = []

        let outcome = await ExportOrchestrator.exportPNGSequence(
            snapshots: snapshots,
            resolveExportDirectory: { dirURL },
            encodeFrame: { snapshot, _ in encodedIndices.append(snapshot.orderIndex) }
        )

        XCTAssertEqual(outcome, .exported(frameCount: 2, directoryURL: dirURL))
        XCTAssertEqual(encodedIndices, [0, 1])
    }

    func testExportPNGSequenceReturnsFailedWhenEncoderThrows() async {
        let snapshot = ExportFrameSnapshot(
            frameID: UUID(),
            orderIndex: 0,
            compositeImage: makeImage(width: 2, height: 2)
        )

        let outcome = await ExportOrchestrator.exportPNGSequence(
            snapshots: [snapshot],
            resolveExportDirectory: { URL(fileURLWithPath: "/tmp/export-seq") },
            encodeFrame: { _, _ in throw ExportTestError.encoderFailed }
        )

        guard case let .failed(message) = outcome else {
            XCTFail("Expected failed outcome, got \(outcome)")
            return
        }
        XCTAssertFalse(message.isEmpty)
    }

    // MARK: - Helpers

    private func makeArtwork(name: String, width: Int, height: Int) -> ImportedArtwork {
        ImportedArtwork(
            url: URL(fileURLWithPath: "/tmp/\(name)"),
            cgImage: makeImage(width: width, height: height)
        )
    }

    private func makeImage(width: Int, height: Int) -> CGImage {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        return context.makeImage()!
    }

    private enum ExportTestError: Error {
        case encoderFailed
    }
}
