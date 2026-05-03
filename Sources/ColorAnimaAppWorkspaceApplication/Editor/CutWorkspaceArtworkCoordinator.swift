import Foundation

public struct CutWorkspaceFrameArtworkState {
    public var outline: ImportedArtwork?
    public var highlightLine: ImportedArtwork?
    public var shadowLine: ImportedArtwork?

    public init(
        outline: ImportedArtwork? = nil,
        highlightLine: ImportedArtwork? = nil,
        shadowLine: ImportedArtwork? = nil
    ) {
        self.outline = outline
        self.highlightLine = highlightLine
        self.shadowLine = shadowLine
    }

    public subscript(kind: CutAssetKind) -> ImportedArtwork? {
        get {
            switch kind {
            case .outline:
                outline
            case .highlightLine:
                highlightLine
            case .shadowLine:
                shadowLine
            }
        }
        set {
            switch kind {
            case .outline:
                outline = newValue
            case .highlightLine:
                highlightLine = newValue
            case .shadowLine:
                shadowLine = newValue
            }
        }
    }

    public var hasAnyArtwork: Bool {
        CutAssetKind.allCases.contains { self[$0] != nil }
    }
}

public struct CutWorkspaceArtworkFrameRecord: Identifiable, Hashable, Equatable, Sendable {
    public var id: UUID
    public var assetCatalog: CutAssetCatalog

    public init(id: UUID, assetCatalog: CutAssetCatalog = CutAssetCatalog()) {
        self.id = id
        self.assetCatalog = assetCatalog
    }
}

public struct CutWorkspaceArtworkState {
    public var activeFrameID: UUID?
    public var fallbackFrameID: UUID?
    public var activeArtwork: CutWorkspaceFrameArtworkState
    public var cachedArtworkByFrameID: [UUID: CutWorkspaceFrameArtworkState]
    public var assetCatalogByFrameID: [UUID: CutAssetCatalog]
    public var isDirty: Bool
    public var errorMessage: String?
    public var needsGuideFillMapRecompute: Bool
    public var needsRegionExtractionReset: Bool
    public var needsPreviewRefresh: Bool

    public init(
        activeFrameID: UUID? = nil,
        fallbackFrameID: UUID? = nil,
        activeArtwork: CutWorkspaceFrameArtworkState = CutWorkspaceFrameArtworkState(),
        cachedArtworkByFrameID: [UUID: CutWorkspaceFrameArtworkState] = [:],
        assetCatalogByFrameID: [UUID: CutAssetCatalog] = [:],
        isDirty: Bool = false,
        errorMessage: String? = nil,
        needsGuideFillMapRecompute: Bool = false,
        needsRegionExtractionReset: Bool = false,
        needsPreviewRefresh: Bool = false
    ) {
        self.activeFrameID = activeFrameID
        self.fallbackFrameID = fallbackFrameID
        self.activeArtwork = activeArtwork
        self.cachedArtworkByFrameID = cachedArtworkByFrameID
        self.assetCatalogByFrameID = assetCatalogByFrameID
        self.isDirty = isDirty
        self.errorMessage = errorMessage
        self.needsGuideFillMapRecompute = needsGuideFillMapRecompute
        self.needsRegionExtractionReset = needsRegionExtractionReset
        self.needsPreviewRefresh = needsPreviewRefresh
    }

    public var resolvedActiveFrameID: UUID? {
        activeFrameID ?? fallbackFrameID
    }
}

public enum CutWorkspaceArtworkCoordinator {
    public static func artwork(
        for kind: CutAssetKind,
        frameID: UUID? = nil,
        in state: CutWorkspaceArtworkState
    ) -> ImportedArtwork? {
        let resolvedFrameID = frameID ?? state.resolvedActiveFrameID
        if resolvedFrameID == state.resolvedActiveFrameID {
            return state.activeArtwork[kind]
        }
        guard let resolvedFrameID else {
            return state.activeArtwork[kind]
        }
        return state.cachedArtworkByFrameID[resolvedFrameID]?[kind]
    }

    public static func hasCachedArtworkState(
        for frameID: UUID,
        in state: CutWorkspaceArtworkState
    ) -> Bool {
        state.cachedArtworkByFrameID[frameID] != nil
    }

    public static func applyLoadedArtwork(
        _ artwork: ImportedArtwork?,
        for kind: CutAssetKind,
        in state: inout CutWorkspaceArtworkState
    ) {
        state.activeArtwork[kind] = artwork
        updateCachedArtwork(artwork, for: kind, in: &state)
        state.needsGuideFillMapRecompute = true
    }

    public static func importArtwork(
        _ artwork: ImportedArtwork,
        assetRef: CutAssetRef?,
        kind: CutAssetKind,
        in state: inout CutWorkspaceArtworkState
    ) {
        state.activeArtwork[kind] = artwork
        updateCachedArtwork(artwork, for: kind, in: &state)

        if let frameID = state.resolvedActiveFrameID, let assetRef {
            var catalog = state.assetCatalogByFrameID[frameID] ?? CutAssetCatalog()
            catalog[kind] = assetRef
            state.assetCatalogByFrameID[frameID] = catalog
        }

        state.needsRegionExtractionReset = true
        state.needsPreviewRefresh = true
        state.isDirty = true
        state.errorMessage = nil
    }

    public static func cacheActiveFrameArtworkState(
        in state: inout CutWorkspaceArtworkState
    ) {
        guard let frameID = state.resolvedActiveFrameID else { return }
        state.cachedArtworkByFrameID[frameID] = state.activeArtwork
    }

    public static func applyArtworkState(
        _ artworkState: CutWorkspaceFrameArtworkState?,
        in state: inout CutWorkspaceArtworkState
    ) {
        state.activeArtwork = artworkState ?? CutWorkspaceFrameArtworkState()
    }

    public static func resetArtworkState(in state: inout CutWorkspaceArtworkState) {
        state.activeArtwork = CutWorkspaceFrameArtworkState()
        state.cachedArtworkByFrameID = [:]
        state.needsGuideFillMapRecompute = true
    }

    public static func rebindPersistedArtworkURLs(
        frames: [CutWorkspaceArtworkFrameRecord],
        cutFolderURL: URL,
        in state: inout CutWorkspaceArtworkState
    ) {
        let activeFrameID = state.resolvedActiveFrameID

        for frame in frames {
            state.assetCatalogByFrameID[frame.id] = frame.assetCatalog

            for kind in CutAssetKind.allCases {
                guard let assetRef = frame.assetCatalog[kind],
                      let artwork = artwork(for: kind, frameID: frame.id, in: state) else {
                    continue
                }

                let reboundURL = cutFolderURL
                    .appendingPathComponent(assetRef.relativePath, isDirectory: false)
                    .standardizedFileURL
                let reboundArtwork = ImportedArtwork(
                    url: reboundURL,
                    cgImage: artwork.cgImage,
                    size: artwork.size
                )

                if frame.id == activeFrameID {
                    applyLoadedArtwork(reboundArtwork, for: kind, in: &state)
                } else {
                    var cachedArtwork = state.cachedArtworkByFrameID[frame.id] ?? CutWorkspaceFrameArtworkState()
                    cachedArtwork[kind] = reboundArtwork
                    state.cachedArtworkByFrameID[frame.id] = cachedArtwork
                }
            }
        }
    }

    private static func updateCachedArtwork(
        _ artwork: ImportedArtwork?,
        for kind: CutAssetKind,
        in state: inout CutWorkspaceArtworkState
    ) {
        guard let frameID = state.resolvedActiveFrameID else { return }
        var cachedArtwork = state.cachedArtworkByFrameID[frameID] ?? CutWorkspaceFrameArtworkState()
        cachedArtwork[kind] = artwork
        state.cachedArtworkByFrameID[frameID] = cachedArtwork
    }
}
