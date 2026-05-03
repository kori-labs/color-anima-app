import CoreGraphics
import XCTest
@testable import ColorAnimaAppWorkspaceApplication

final class CutWorkspaceSequenceImportCoordinatorTests: XCTestCase {
    func testValidateImportedArtworkResolutionReturnsNilForMatchingResolution() throws {
        let artwork = try makeArtwork(width: 4, height: 3)

        let message = CutWorkspaceSequenceImportCoordinator.validateImportedArtworkResolution(
            artwork,
            expectedResolution: ProjectCanvasResolution(width: 4, height: 3),
            kind: .outline
        )

        XCTAssertNil(message)
    }

    func testValidateImportedArtworkResolutionBuildsKindSpecificMessage() throws {
        let artwork = try makeArtwork(width: 5, height: 3)

        let message = CutWorkspaceSequenceImportCoordinator.validateImportedArtworkResolution(
            artwork,
            expectedResolution: ProjectCanvasResolution(width: 4, height: 3),
            kind: .highlightLine
        )

        XCTAssertEqual(
            message,
            "Highlight Line image must match the project resolution of 4x3. Imported artwork is 5x3."
        )
    }

    func testResolveTargetFrameIDsExpandsSingleEmptyFrame() throws {
        let existingFrameID = UUID()
        let createdA = UUID()
        let createdB = UUID()
        var created = [createdA, createdB]

        let frameIDs = try CutWorkspaceSequenceImportCoordinator.resolveTargetFrameIDs(
            importedCount: 3,
            kind: .outline,
            orderedFrames: [
                CutWorkspaceSequenceFrameState(id: existingFrameID)
            ],
            createFrame: { created.removeFirst() }
        )

        XCTAssertEqual(frameIDs, [existingFrameID, createdA, createdB])
    }

    func testResolveTargetFrameIDsRejectsFrameCountMismatchWhenFrameIsNotEmpty() {
        let existingFrameID = UUID()

        XCTAssertThrowsError(
            try CutWorkspaceSequenceImportCoordinator.resolveTargetFrameIDs(
                importedCount: 2,
                kind: .shadowLine,
                orderedFrames: [
                    CutWorkspaceSequenceFrameState(
                        id: existingFrameID,
                        hasLoadedArtwork: true
                    )
                ],
                createFrame: { UUID() }
            )
        ) { error in
            XCTAssertEqual(
                error as? AssetSequenceImportError,
                .frameCountMismatch(kindTitle: "Shadow Line", importedCount: 2, existingCount: 1)
            )
        }
    }

    func testImportAssetSequenceValidatesBeforeCreatingFrames() throws {
        let valid = try makeArtwork(width: 2, height: 2)
        let invalid = try makeArtwork(width: 3, height: 2)
        var createFrameCallCount = 0

        XCTAssertThrowsError(
            try CutWorkspaceSequenceImportCoordinator.importAssetSequence(
                kind: .outline,
                artworks: [valid, invalid],
                expectedResolution: ProjectCanvasResolution(width: 2, height: 2),
                orderedFrames: [CutWorkspaceSequenceFrameState(id: UUID())],
                createFrame: {
                    createFrameCallCount += 1
                    return UUID()
                },
                selectFrame: { _ in },
                prepareImportedAsset: { _, kind, _ in
                    CutAssetRef(kind: kind, relativePath: "outline.png")
                },
                importArtwork: { _, _, _ in }
            )
        ) { error in
            XCTAssertEqual(
                error as? AssetSequenceImportError,
                .invalidResolution(
                    frameLabel: "#002",
                    message: "Outline image must match the project resolution of 2x2. Imported artwork is 3x2."
                )
            )
        }

        XCTAssertEqual(createFrameCallCount, 0)
    }

    func testImportAssetSequenceSelectsFramesAndReturnsFirstTarget() throws {
        let frameA = UUID()
        let frameB = UUID()
        let artworks = [
            try makeArtwork(width: 2, height: 2),
            try makeArtwork(width: 2, height: 2),
        ]
        var selectedFrameIDs: [UUID] = []
        var prepared: [(URL, CutAssetKind, UUID)] = []
        var imported: [(URL, CutAssetRef, CutAssetKind)] = []

        let firstTarget = try CutWorkspaceSequenceImportCoordinator.importAssetSequence(
            kind: .outline,
            artworks: artworks,
            expectedResolution: ProjectCanvasResolution(width: 2, height: 2),
            orderedFrames: [
                CutWorkspaceSequenceFrameState(id: frameA),
                CutWorkspaceSequenceFrameState(id: frameB),
            ],
            createFrame: { UUID() },
            selectFrame: { selectedFrameIDs.append($0) },
            prepareImportedAsset: { url, kind, frameID in
                prepared.append((url, kind, frameID))
                return CutAssetRef(kind: kind, relativePath: "\(frameID.uuidString).png")
            },
            importArtwork: { artwork, assetRef, kind in
                imported.append((artwork.url, assetRef, kind))
            }
        )

        XCTAssertEqual(firstTarget, frameA)
        XCTAssertEqual(selectedFrameIDs, [frameA, frameB, frameA])
        XCTAssertEqual(prepared.map(\.2), [frameA, frameB])
        XCTAssertEqual(imported.map(\.2), [.outline, .outline])
    }

    func testEmptySequenceThrowsKindSpecificError() {
        XCTAssertThrowsError(
            try CutWorkspaceSequenceImportCoordinator.importAssetSequence(
                kind: .highlightLine,
                artworks: [],
                expectedResolution: ProjectCanvasResolution(width: 2, height: 2),
                orderedFrames: [CutWorkspaceSequenceFrameState(id: UUID())],
                createFrame: { UUID() },
                selectFrame: { _ in },
                prepareImportedAsset: { _, kind, _ in CutAssetRef(kind: kind, relativePath: "asset.png") },
                importArtwork: { _, _, _ in }
            )
        ) { error in
            XCTAssertEqual(
                error as? AssetSequenceImportError,
                .emptySequence(kindTitle: "Highlight Line")
            )
        }
    }

    private func makeArtwork(width: Int, height: Int) throws -> ImportedArtwork {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw TestImageError.failedToCreateContext
        }
        context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        guard let image = context.makeImage() else {
            throw TestImageError.failedToCreateImage
        }
        return ImportedArtwork(
            url: URL(fileURLWithPath: "/tmp/\(UUID().uuidString).png"),
            cgImage: image
        )
    }

    private enum TestImageError: Error {
        case failedToCreateContext
        case failedToCreateImage
    }
}
