import ColorAnimaAppEngine
import CoreGraphics
import Foundation
import XCTest
@testable import ColorAnimaAppWorkspaceApplication

// Tests for PNGSequenceExportService invariants:
//   1. Deterministic naming  — frame-0001.png, frame-0002.png, … (4-digit, 1-based)
//   2. Deterministic overwrite — pre-existing file is replaced in place; no auto-suffix
//   3. Sorted output — writtenURLs are ordered by orderIndex regardless of snapshot input order
//   4. Directory error — throws directoryNotWritable for missing/non-writable target
//   5. ExportOrchestrator callback — makeEncodeFrameCallback produces correctly named files
@MainActor
final class PNGSequenceExportServiceTests: XCTestCase {

    private let client = PNGSequenceEncoderClient()

    // MARK: - Invariant 1: Deterministic naming

    /// Written filenames must be frame-0001.png … frame-NNNN.png exactly.
    /// 12-frame fixture exercises the 4-digit zero-padding rule.
    func testExportNamesFilesWithFourDigitOneBasedIndex() throws {
        let frameCount = 12
        let snapshots = makeSnapshots(count: frameCount)
        let tempDir = try makeTempDirectory(named: "naming")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        _ = try PNGSequenceExportService.export(
            snapshots: snapshots,
            to: tempDir,
            client: client
        )

        let written = try FileManager.default
            .contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
            .map(\.lastPathComponent)
            .sorted()

        let expected = (1...frameCount).map { String(format: "frame-%04d.png", $0) }
        XCTAssertEqual(written, expected)
    }

    /// ExportResult.writtenURLs must be ordered by orderIndex regardless of
    /// the order snapshots were supplied.
    func testExportWrittenURLsOrderedByOrderIndex() throws {
        var snapshots = makeSnapshots(count: 4)
        snapshots = [snapshots[3], snapshots[1], snapshots[0], snapshots[2]]  // scramble

        let tempDir = try makeTempDirectory(named: "order")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let report = try PNGSequenceExportService.export(
            snapshots: snapshots,
            to: tempDir,
            client: client
        )

        let filenames = report.writtenURLs.map(\.lastPathComponent)
        let expected = (1...4).map { String(format: "frame-%04d.png", $0) }
        XCTAssertEqual(filenames, expected)
    }

    // MARK: - Invariant 2: Deterministic overwrite

    /// A pre-existing frame-0001.png with different content must be overwritten
    /// in place. No additional files (auto-suffix copies) may appear.
    func testExportOverwritesExistingFilesWithoutAutoSuffix() throws {
        let snapshots = makeSnapshots(count: 2)
        let tempDir = try makeTempDirectory(named: "overwrite")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Write stale sentinel bytes to prove overwrite happened.
        let staleURL = tempDir.appendingPathComponent("frame-0001.png")
        let staleBytes = Data(repeating: 0xAA, count: 32)
        try staleBytes.write(to: staleURL)

        _ = try PNGSequenceExportService.export(
            snapshots: snapshots,
            to: tempDir,
            client: client
        )

        let contents = try FileManager.default
            .contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
        XCTAssertEqual(contents.count, 2, "auto-suffix must not create extra files")

        let overwrittenData = try Data(contentsOf: staleURL)
        XCTAssertNotEqual(overwrittenData.prefix(4), staleBytes.prefix(4),
                          "frame-0001.png must be overwritten with new PNG content")
    }

    // MARK: - Invariant 3: Report fields

    func testExportReportFrameCountMatchesSnapshotCount() throws {
        let frameCount = 5
        let snapshots = makeSnapshots(count: frameCount)
        let tempDir = try makeTempDirectory(named: "count")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let report = try PNGSequenceExportService.export(
            snapshots: snapshots,
            to: tempDir,
            client: client
        )

        XCTAssertEqual(report.frameCount, frameCount)
        XCTAssertEqual(report.writtenURLs.count, frameCount)
        XCTAssertEqual(report.directoryURL, tempDir)
        // kernel is not yet available — ImageIO fallback used
        XCTAssertFalse(report.kernelExecuted)
    }

    // MARK: - Invariant 4: Directory error

    func testExportThrowsDirectoryNotWritableForMissingDirectory() {
        let snapshots = makeSnapshots(count: 1)
        let nonExistentDir = URL(fileURLWithPath: "/tmp/ca-nonexistent-\(UUID().uuidString)")

        XCTAssertThrowsError(
            try PNGSequenceExportService.export(
                snapshots: snapshots,
                to: nonExistentDir,
                client: client
            )
        ) { error in
            guard case PNGSequenceExportError.directoryNotWritable(let url) = error else {
                XCTFail("Expected directoryNotWritable, got \(error)")
                return
            }
            XCTAssertEqual(url, nonExistentDir)
        }
    }

    // MARK: - Invariant 5: ExportOrchestrator callback integration

    /// makeEncodeFrameCallback must produce correctly named files when
    /// composed with ExportOrchestrator.exportPNGSequence.
    func testMakeEncodeFrameCallbackProducesNamedFilesViaOrchestrator() async throws {
        let frameCount = 3
        let snapshots = makeSnapshots(count: frameCount)
        let tempDir = try makeTempDirectory(named: "callback")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let callback = PNGSequenceExportService.makeEncodeFrameCallback(client: client)
        let outcome = await ExportOrchestrator.exportPNGSequence(
            snapshots: snapshots,
            resolveExportDirectory: { tempDir },
            encodeFrame: callback
        )

        guard case let .exported(count, dirURL) = outcome else {
            XCTFail("Expected .exported, got \(outcome)")
            return
        }
        XCTAssertEqual(count, frameCount)
        XCTAssertEqual(dirURL, tempDir)

        let written = try FileManager.default
            .contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
            .map(\.lastPathComponent)
            .sorted()
        let expected = (1...frameCount).map { String(format: "frame-%04d.png", $0) }
        XCTAssertEqual(written, expected)
    }

    /// Callback respects the naming policy: orderIndex 0 → frame-0001.png.
    func testCallbackUsesOneBasedNamingFromZeroBasedOrderIndex() async throws {
        let snapshot = ExportFrameSnapshot(
            frameID: UUID(),
            orderIndex: 0,
            compositeImage: makeImage(width: 4, height: 4)
        )
        let tempDir = try makeTempDirectory(named: "naming-policy")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let callback = PNGSequenceExportService.makeEncodeFrameCallback(client: client)
        try await callback(snapshot, tempDir)

        XCTAssertTrue(
            FileManager.default.fileExists(atPath: tempDir.appendingPathComponent("frame-0001.png").path),
            "orderIndex 0 must produce frame-0001.png"
        )
    }

    // MARK: - Helpers

    private func makeSnapshots(count: Int) -> [ExportFrameSnapshot] {
        (0..<count).map { index in
            ExportFrameSnapshot(
                frameID: UUID(),
                orderIndex: index,
                compositeImage: makeImage(width: 4, height: 4)
            )
        }
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

    private func makeTempDirectory(named name: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ca-png-svc-\(name)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
