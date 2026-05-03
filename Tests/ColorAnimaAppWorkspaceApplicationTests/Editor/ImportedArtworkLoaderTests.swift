import CoreGraphics
import ColorAnimaAppWorkspaceApplication
import ImageIO
import UniformTypeIdentifiers
import XCTest

final class ImportedArtworkLoaderTests: XCTestCase {
    func testLoadDecodesImageAndCanvasRasterImage() throws {
        let directory = try makeTemporaryDirectory(named: "loader-single")
        defer { try? FileManager.default.removeItem(at: directory) }

        let url = directory.appendingPathComponent("artwork.png")
        try writePNG(makeSolidImage(width: 3, height: 2), to: url)

        let artwork = try ImportedArtworkLoader.load(from: url)

        XCTAssertEqual(artwork.url, url)
        XCTAssertEqual(artwork.size, CGSize(width: 3, height: 2))
        XCTAssertEqual(artwork.canvasRasterImage.size, CGSize(width: 3, height: 2))
    }

    func testLoadThrowsForMissingImage() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("missing-\(UUID().uuidString).png")

        XCTAssertThrowsError(try ImportedArtworkLoader.load(from: url))
    }

    func testLoadParallelReturnsEmptyArrayForNoURLs() async {
        let results = await ImportedArtworkLoader.loadParallel(urls: [])

        XCTAssertTrue(results.isEmpty)
    }

    func testLoadParallelPreservesInputOrder() async throws {
        let directory = try makeTemporaryDirectory(named: "loader-parallel-order")
        defer { try? FileManager.default.removeItem(at: directory) }

        let urls = try (0..<6).map { index in
            let url = directory.appendingPathComponent("frame-\(index).png")
            try writePNG(makeSolidImage(width: 4 + index, height: 3), to: url)
            return url
        }

        let results = await ImportedArtworkLoader.loadParallel(urls: urls, maxConcurrent: 3)

        XCTAssertEqual(results.count, urls.count)
        for (expectedIndex, result) in results.enumerated() {
            switch result {
            case let .success(index, url, artwork):
                XCTAssertEqual(index, expectedIndex)
                XCTAssertEqual(url, urls[expectedIndex])
                XCTAssertEqual(artwork.size.width, CGFloat(4 + expectedIndex))
            case let .failure(index, url, error):
                XCTFail("Unexpected failure at \(index) url=\(url): \(error)")
            }
        }
    }

    func testLoadParallelIsolatesPerURLFailures() async throws {
        let directory = try makeTemporaryDirectory(named: "loader-parallel-partial")
        defer { try? FileManager.default.removeItem(at: directory) }

        let first = directory.appendingPathComponent("ok-0.png")
        let missing = directory.appendingPathComponent("missing.png")
        let last = directory.appendingPathComponent("ok-2.png")
        try writePNG(makeSolidImage(width: 4, height: 4), to: first)
        try writePNG(makeSolidImage(width: 5, height: 4), to: last)

        let results = await ImportedArtworkLoader.loadParallel(
            urls: [first, missing, last],
            maxConcurrent: 2
        )

        XCTAssertEqual(results.count, 3)
        XCTAssertTrue(results[0].isSuccess)
        XCTAssertTrue(results[1].isFailure)
        XCTAssertTrue(results[2].isSuccess)
    }

    func testDefaultMaxConcurrentIsBounded() {
        let cap = ImportedArtworkLoader.defaultMaxConcurrent

        XCTAssertGreaterThanOrEqual(cap, 1)
        XCTAssertLessThanOrEqual(cap, 4)
    }

    private func makeTemporaryDirectory(named name: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("color-anima-\(name)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func makeSolidImage(width: Int, height: Int) throws -> CGImage {
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        for offset in stride(from: 0, to: pixels.count, by: 4) {
            pixels[offset] = 64
            pixels[offset + 1] = 128
            pixels[offset + 2] = 192
            pixels[offset + 3] = 255
        }

        return try pixels.withUnsafeMutableBytes { bytes in
            guard let context = CGContext(
                data: bytes.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ), let image = context.makeImage() else {
                throw TestImageError.makeImageFailed
            }
            return image
        }
    }

    private func writePNG(_ image: CGImage, to url: URL) throws {
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            throw TestImageError.makeDestinationFailed
        }

        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw TestImageError.finalizeFailed
        }
    }
}

private extension ImportedArtworkLoader.ParallelLoadResult {
    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }

    var isFailure: Bool {
        if case .failure = self { return true }
        return false
    }
}

private enum TestImageError: Error {
    case makeImageFailed
    case makeDestinationFailed
    case finalizeFailed
}
