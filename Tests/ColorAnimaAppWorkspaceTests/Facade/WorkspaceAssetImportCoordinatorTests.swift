import CoreGraphics
import ColorAnimaAppWorkspaceApplication
import Foundation
import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import ColorAnimaAppWorkspace

@MainActor
final class WorkspaceAssetImportCoordinatorTests: XCTestCase {
    func testImportAssetLoadsFolderImagesInSortedOrder() throws {
        let directory = try makeTemporaryDirectory(named: "asset-sequence")
        defer { try? FileManager.default.removeItem(at: directory) }

        try writePNG(named: "shot-10.png", to: directory)
        try writePNG(named: "shot-2.png", to: directory)
        try writePNG(named: "shot-1.png", to: directory)
        try "ignore".write(to: directory.appendingPathComponent("notes.txt"), atomically: true, encoding: .utf8)

        let prompt = MockWorkspaceAssetImportPrompting()
        prompt.directoryResponses = [directory]
        let recorder = AssetImportRecorder()
        let coordinator = makeCoordinator(prompting: prompt, recorder: recorder)

        coordinator.importAsset(.outline)

        XCTAssertEqual(prompt.events, [.openDirectory(title: "Import Outline Frames Folder")])
        XCTAssertEqual(recorder.assetSequenceImports, [
            AssetImportRecorder.AssetSequenceImport(
                kind: .outline,
                filenames: ["shot-1.png", "shot-2.png", "shot-10.png"]
            ),
        ])
        XCTAssertTrue(recorder.errors.isEmpty)
    }

    func testImportAssetCancellationDoesNotDispatch() {
        let prompt = MockWorkspaceAssetImportPrompting()
        prompt.directoryResponses = [nil]
        let recorder = AssetImportRecorder()
        let coordinator = makeCoordinator(prompting: prompt, recorder: recorder)

        coordinator.importAsset(.highlightLine)

        XCTAssertEqual(prompt.events, [.openDirectory(title: "Import Highlight Line Frames Folder")])
        XCTAssertTrue(recorder.assetSequenceImports.isEmpty)
        XCTAssertTrue(recorder.errors.isEmpty)
    }

    func testImportAssetReportsMissingImages() throws {
        let directory = try makeTemporaryDirectory(named: "empty-highlight")
        defer { try? FileManager.default.removeItem(at: directory) }

        let prompt = MockWorkspaceAssetImportPrompting()
        prompt.directoryResponses = [directory]
        let recorder = AssetImportRecorder()
        let coordinator = makeCoordinator(prompting: prompt, recorder: recorder)

        coordinator.importAsset(.highlightLine)

        XCTAssertTrue(recorder.assetSequenceImports.isEmpty)
        XCTAssertEqual(recorder.errors, ["Highlight Line folder does not contain any image files."])
    }

    func testImportUnifiedLayersPromptsAndDispatchesImage() throws {
        let directory = try makeTemporaryDirectory(named: "unified-image")
        defer { try? FileManager.default.removeItem(at: directory) }
        let imageURL = try writePNG(named: "composite.png", to: directory)

        let prompt = MockWorkspaceAssetImportPrompting()
        prompt.imageResponses = [imageURL]
        let recorder = AssetImportRecorder()
        let coordinator = makeCoordinator(prompting: prompt, recorder: recorder)

        coordinator.importUnifiedLayers()

        XCTAssertEqual(prompt.events, [.openImage(title: "Import Composite Layer Image")])
        XCTAssertEqual(recorder.unifiedLayerImages, [imageURL])
        XCTAssertTrue(recorder.errors.isEmpty)
    }

    func testImportUnifiedLayerSequenceDispatchesSortedImageURLs() throws {
        let directory = try makeTemporaryDirectory(named: "unified-sequence")
        defer { try? FileManager.default.removeItem(at: directory) }

        try writePNG(named: "frame-10.png", to: directory)
        try writePNG(named: "frame-2.png", to: directory)
        try writePNG(named: "frame-1.png", to: directory)

        let prompt = MockWorkspaceAssetImportPrompting()
        prompt.directoryResponses = [directory]
        let recorder = AssetImportRecorder()
        let coordinator = makeCoordinator(prompting: prompt, recorder: recorder)

        coordinator.importUnifiedLayerSequence()

        XCTAssertEqual(prompt.events, [.openDirectory(title: "Import Composite Layer Frames Folder")])
        XCTAssertEqual(recorder.unifiedLayerSequences, [[
            "frame-1.png",
            "frame-2.png",
            "frame-10.png",
        ]])
        XCTAssertTrue(recorder.errors.isEmpty)
    }

    func testImportUnifiedLayerSequenceReportsMissingImages() throws {
        let directory = try makeTemporaryDirectory(named: "empty-composite")
        defer { try? FileManager.default.removeItem(at: directory) }

        let prompt = MockWorkspaceAssetImportPrompting()
        prompt.directoryResponses = [directory]
        let recorder = AssetImportRecorder()
        let coordinator = makeCoordinator(prompting: prompt, recorder: recorder)

        coordinator.importUnifiedLayerSequence()

        XCTAssertTrue(recorder.unifiedLayerSequences.isEmpty)
        XCTAssertEqual(recorder.errors, ["\(directory.lastPathComponent) folder does not contain any image files."])
    }

    func testImportTriSequenceLoadsAllSelectedLayerFolders() throws {
        let directory = try makeTemporaryDirectory(named: "tri-sequence")
        defer { try? FileManager.default.removeItem(at: directory) }
        let outline = try makeDirectory(named: "outline", under: directory)
        let highlight = try makeDirectory(named: "highlight", under: directory)
        let shadow = try makeDirectory(named: "shadow", under: directory)

        for name in ["frame-001.png", "frame-002.png"] {
            try writePNG(named: name, to: outline)
            try writePNG(named: name, to: highlight)
            try writePNG(named: name, to: shadow)
        }

        let recorder = AssetImportRecorder()
        let coordinator = makeCoordinator(prompting: MockWorkspaceAssetImportPrompting(), recorder: recorder)

        coordinator.importTriSequence(
            outlineDirectoryURL: outline,
            highlightDirectoryURL: highlight,
            shadowDirectoryURL: shadow
        )

        XCTAssertEqual(recorder.triSequenceImports, [
            AssetImportRecorder.TriSequenceImport(
                outlineFilenames: ["frame-001.png", "frame-002.png"],
                highlightFilenames: ["frame-001.png", "frame-002.png"],
                shadowFilenames: ["frame-001.png", "frame-002.png"],
                frameCount: 2
            ),
        ])
        XCTAssertTrue(recorder.errors.isEmpty)
    }

    func testImportTriSequenceAllowsOutlineOnlyPlan() throws {
        let directory = try makeTemporaryDirectory(named: "tri-sequence-outline-only")
        defer { try? FileManager.default.removeItem(at: directory) }
        let outline = try makeDirectory(named: "outline", under: directory)
        try writePNG(named: "frame-001.png", to: outline)

        let recorder = AssetImportRecorder()
        let coordinator = makeCoordinator(prompting: MockWorkspaceAssetImportPrompting(), recorder: recorder)

        coordinator.importTriSequence(
            outlineDirectoryURL: outline,
            highlightDirectoryURL: nil,
            shadowDirectoryURL: nil
        )

        XCTAssertEqual(recorder.triSequenceImports, [
            AssetImportRecorder.TriSequenceImport(
                outlineFilenames: ["frame-001.png"],
                highlightFilenames: nil,
                shadowFilenames: nil,
                frameCount: 1
            ),
        ])
        XCTAssertTrue(recorder.errors.isEmpty)
    }

    func testImportTriSequenceReportsMissingOutlineImages() throws {
        let directory = try makeTemporaryDirectory(named: "tri-sequence-empty-outline")
        defer { try? FileManager.default.removeItem(at: directory) }
        let outline = try makeDirectory(named: "outline", under: directory)

        let recorder = AssetImportRecorder()
        let coordinator = makeCoordinator(prompting: MockWorkspaceAssetImportPrompting(), recorder: recorder)

        coordinator.importTriSequence(
            outlineDirectoryURL: outline,
            highlightDirectoryURL: nil,
            shadowDirectoryURL: nil
        )

        XCTAssertTrue(recorder.triSequenceImports.isEmpty)
        XCTAssertEqual(recorder.errors, ["Outline folder does not contain any image files."])
    }

    private func makeCoordinator(
        prompting: MockWorkspaceAssetImportPrompting,
        recorder: AssetImportRecorder
    ) -> WorkspaceAssetImportCoordinator {
        WorkspaceAssetImportCoordinator(
            prompting: prompting,
            importAssetSequence: { kind, artworks in
                recorder.assetSequenceImports.append(
                    AssetImportRecorder.AssetSequenceImport(
                        kind: kind,
                        filenames: artworks.map { $0.url.lastPathComponent }
                    )
                )
            },
            importUnifiedLayers: { url in
                recorder.unifiedLayerImages.append(url)
            },
            importUnifiedLayerSequence: { urls in
                recorder.unifiedLayerSequences.append(urls.map(\.lastPathComponent))
            },
            importTriSequence: { plan in
                recorder.triSequenceImports.append(
                    AssetImportRecorder.TriSequenceImport(
                        outlineFilenames: plan.outlineArtworks.map { $0.url.lastPathComponent },
                        highlightFilenames: plan.highlightArtworks?.map { $0.url.lastPathComponent },
                        shadowFilenames: plan.shadowArtworks?.map { $0.url.lastPathComponent },
                        frameCount: plan.frameCount
                    )
                )
            },
            reportError: { message in
                recorder.errors.append(message)
            }
        )
    }

    private func makeDirectory(named name: String, under rootURL: URL) throws -> URL {
        let url = rootURL.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func makeTemporaryDirectory(named name: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("color-anima-\(name)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @discardableResult
    private func writePNG(named filename: String, to directoryURL: URL) throws -> URL {
        let url = directoryURL.appendingPathComponent(filename, isDirectory: false)
        try writePNG(makeSolidImage(width: 2, height: 2), to: url)
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

@MainActor
private final class AssetImportRecorder {
    struct AssetSequenceImport: Equatable {
        var kind: CutAssetKind
        var filenames: [String]
    }

    struct TriSequenceImport: Equatable {
        var outlineFilenames: [String]
        var highlightFilenames: [String]?
        var shadowFilenames: [String]?
        var frameCount: Int
    }

    var assetSequenceImports: [AssetSequenceImport] = []
    var unifiedLayerImages: [URL] = []
    var unifiedLayerSequences: [[String]] = []
    var triSequenceImports: [TriSequenceImport] = []
    var errors: [String] = []
}

@MainActor
private final class MockWorkspaceAssetImportPrompting: WorkspaceAssetImportPrompting {
    enum Event: Equatable {
        case openImage(title: String)
        case openDirectory(title: String)
    }

    var events: [Event] = []
    var imageResponses: [URL?] = []
    var directoryResponses: [URL?] = []

    func openImage(title: String) throws -> URL? {
        events.append(.openImage(title: title))
        return imageResponses.isEmpty ? nil : imageResponses.removeFirst()
    }

    func openDirectory(title: String) throws -> URL? {
        events.append(.openDirectory(title: title))
        return directoryResponses.isEmpty ? nil : directoryResponses.removeFirst()
    }
}

private enum TestImageError: Error {
    case makeImageFailed
    case makeDestinationFailed
    case finalizeFailed
}
