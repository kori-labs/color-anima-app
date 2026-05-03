import Foundation

public struct CutWorkspaceSequenceFrameState: Hashable, Equatable, Sendable {
    public var id: UUID
    public var assetCatalog: CutAssetCatalog
    public var hasLoadedArtwork: Bool
    public var regionCount: Int

    public init(
        id: UUID = UUID(),
        assetCatalog: CutAssetCatalog = CutAssetCatalog(),
        hasLoadedArtwork: Bool = false,
        regionCount: Int = 0
    ) {
        self.id = id
        self.assetCatalog = assetCatalog
        self.hasLoadedArtwork = hasLoadedArtwork
        self.regionCount = regionCount
    }
}

public enum CutWorkspaceSequenceImportCoordinator {
    public static func validateImportedArtworkResolution(
        _ artwork: ImportedArtwork,
        expectedResolution: ProjectCanvasResolution,
        kind: CutAssetKind
    ) -> String? {
        let actual = ProjectCanvasResolution(
            width: Int(artwork.size.width.rounded()),
            height: Int(artwork.size.height.rounded())
        )
        guard actual == expectedResolution else {
            return "\(displayTitle(for: kind)) image must match the project resolution of \(expectedResolution.width)x\(expectedResolution.height). Imported artwork is \(actual.width)x\(actual.height)."
        }
        return nil
    }

    public static func resolveTargetFrameIDs(
        importedCount: Int,
        kind: CutAssetKind,
        orderedFrames: [CutWorkspaceSequenceFrameState],
        createFrame: () throws -> UUID
    ) throws -> [UUID] {
        guard importedCount > 0 else {
            return []
        }

        guard let existingFrameID = orderedFrames.first?.id else {
            throw AssetSequenceImportError.noTargetFrame
        }

        if canExpandSingleEmptyFrame(orderedFrames) {
            var frameIDs = [existingFrameID]
            while frameIDs.count < importedCount {
                frameIDs.append(try createFrame())
            }
            return frameIDs
        }

        guard orderedFrames.count == importedCount else {
            throw AssetSequenceImportError.frameCountMismatch(
                kindTitle: displayTitle(for: kind),
                importedCount: importedCount,
                existingCount: orderedFrames.count
            )
        }
        return orderedFrames.map(\.id)
    }

    @discardableResult
    public static func importAssetSequence(
        kind: CutAssetKind,
        artworks: [ImportedArtwork],
        expectedResolution: ProjectCanvasResolution,
        orderedFrames: [CutWorkspaceSequenceFrameState],
        createFrame: () throws -> UUID,
        selectFrame: (UUID) -> Void,
        prepareImportedAsset: (_ url: URL, _ kind: CutAssetKind, _ frameID: UUID) throws -> CutAssetRef,
        importArtwork: (_ artwork: ImportedArtwork, _ assetRef: CutAssetRef, _ kind: CutAssetKind) throws -> Void
    ) throws -> UUID? {
        guard artworks.isEmpty == false else {
            throw AssetSequenceImportError.emptySequence(kindTitle: displayTitle(for: kind))
        }

        for (index, artwork) in artworks.enumerated() {
            let frameLabel = "#\(String(format: "%03d", index + 1))"
            if let validationMessage = validateImportedArtworkResolution(
                artwork,
                expectedResolution: expectedResolution,
                kind: kind
            ) {
                throw AssetSequenceImportError.invalidResolution(
                    frameLabel: frameLabel,
                    message: validationMessage
                )
            }
        }

        let targetFrameIDs = try resolveTargetFrameIDs(
            importedCount: artworks.count,
            kind: kind,
            orderedFrames: orderedFrames,
            createFrame: createFrame
        )

        for (frameID, artwork) in zip(targetFrameIDs, artworks) {
            selectFrame(frameID)
            let assetRef = try prepareImportedAsset(artwork.url, kind, frameID)
            try importArtwork(artwork, assetRef, kind)
        }

        if let firstFrameID = targetFrameIDs.first {
            selectFrame(firstFrameID)
        }
        return targetFrameIDs.first
    }

    private static func canExpandSingleEmptyFrame(_ orderedFrames: [CutWorkspaceSequenceFrameState]) -> Bool {
        guard orderedFrames.count == 1, let frame = orderedFrames.first else {
            return false
        }
        let hasPersistedAssets = CutAssetKind.allCases.contains { frame.assetCatalog[$0] != nil }
        return hasPersistedAssets == false
            && frame.hasLoadedArtwork == false
            && frame.regionCount == 0
    }

    private static func displayTitle(for kind: CutAssetKind) -> String {
        switch kind {
        case .outline:
            "Outline"
        case .highlightLine:
            "Highlight Line"
        case .shadowLine:
            "Shadow Line"
        }
    }
}

public enum AssetSequenceImportError: LocalizedError, Equatable {
    case noTargetFrame
    case emptySequence(kindTitle: String)
    case frameCountMismatch(kindTitle: String, importedCount: Int, existingCount: Int)
    case invalidResolution(frameLabel: String, message: String)

    public var errorDescription: String? {
        switch self {
        case .noTargetFrame:
            "Current cut does not contain a target frame."
        case let .emptySequence(kindTitle):
            "\(kindTitle) folder does not contain any image files."
        case let .frameCountMismatch(kindTitle, importedCount, existingCount):
            "\(kindTitle) folder contains \(importedCount) frame(s), but the current cut has \(existingCount) frame(s)."
        case let .invalidResolution(frameLabel, message):
            "Frame \(frameLabel): \(message)"
        }
    }
}
