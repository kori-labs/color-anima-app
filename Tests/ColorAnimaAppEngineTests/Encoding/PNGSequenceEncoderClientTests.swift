import ColorAnimaAppEngine
import CoreGraphics
import Foundation
import XCTest

final class PNGSequenceEncoderClientTests: XCTestCase {

    // MARK: - Availability

    func testClientKernelEncodingIsUnavailableWhileFunctionNotExposed() {
        let client = PNGSequenceEncoderClient()
        XCTAssertFalse(client.isKernelEncodingAvailable)
    }

    // MARK: - ImageIO fallback encoding

    func testEncodeFrameProducesFileWhenGivenValidImage() throws {
        let client = PNGSequenceEncoderClient()
        let image = makeImage(width: 8, height: 8)
        let tempURL = makeTempURL(named: "encode-test.png")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let report = try client.encodeFrame(image: image, to: tempURL)

        XCTAssertEqual(report.fileURL, tempURL)
        XCTAssertFalse(report.kernelExecuted, "kernel not available — should fall back to ImageIO")
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempURL.path),
                      "PNG file must exist on disk after encoding")
    }

    func testEncodeFrameWritesValidPNGSignature() throws {
        let client = PNGSequenceEncoderClient()
        let image = makeImage(width: 4, height: 4)
        let tempURL = makeTempURL(named: "signature-test.png")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        _ = try client.encodeFrame(image: image, to: tempURL)

        let data = try Data(contentsOf: tempURL)
        // PNG magic bytes: 0x89 0x50 0x4E 0x47 0x0D 0x0A 0x1A 0x0A
        let pngMagic: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
        XCTAssertGreaterThanOrEqual(data.count, 8)
        XCTAssertEqual(Array(data.prefix(8)), pngMagic, "Written file must begin with PNG magic bytes")
    }

    func testEncodeFrameOverwritesExistingFile() throws {
        let client = PNGSequenceEncoderClient()
        let image = makeImage(width: 4, height: 4)
        let tempURL = makeTempURL(named: "overwrite-test.png")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        // Write stale sentinel data.
        let stale = Data(repeating: 0xAA, count: 32)
        try stale.write(to: tempURL)

        _ = try client.encodeFrame(image: image, to: tempURL)

        let written = try Data(contentsOf: tempURL)
        XCTAssertNotEqual(written.prefix(4), stale.prefix(4), "Existing file must be overwritten")
    }

    func testEncodeFrameReportEquality() {
        let url = URL(fileURLWithPath: "/tmp/frame-0001.png")
        let a = PNGEncodeFrameReport(fileURL: url, kernelExecuted: false)
        let b = PNGEncodeFrameReport(fileURL: url, kernelExecuted: false)
        XCTAssertEqual(a, b)
    }

    func testEncodeSequenceReportEquality() {
        let dir = URL(fileURLWithPath: "/tmp/export")
        let a = PNGEncodeSequenceReport(directoryURL: dir, frameCount: 5, kernelExecuted: false)
        let b = PNGEncodeSequenceReport(directoryURL: dir, frameCount: 5, kernelExecuted: false)
        XCTAssertEqual(a, b)
    }

    // MARK: - Multiple frame round-trip

    func testEncodeMultipleFramesProducesDistinctFiles() throws {
        let client = PNGSequenceEncoderClient()
        let tempDir = try makeTempDirectory(named: "multi-frame")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let frameCount = 3
        var writtenURLs: [URL] = []
        for i in 1...frameCount {
            let image = makeImage(width: 4, height: 4)
            let fileURL = tempDir.appendingPathComponent(String(format: "frame-%04d.png", i))
            let report = try client.encodeFrame(image: image, to: fileURL)
            writtenURLs.append(report.fileURL)
        }

        XCTAssertEqual(writtenURLs.count, frameCount)
        for url in writtenURLs {
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path),
                          "\(url.lastPathComponent) must exist")
        }
    }

    // MARK: - Helpers

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

    private func makeTempURL(named name: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("ca-png-enc-\(UUID().uuidString)-\(name)")
    }

    private func makeTempDirectory(named name: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ca-png-enc-\(name)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
