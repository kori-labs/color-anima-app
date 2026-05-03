import Foundation

public struct CutWorkspaceFramePresentationFrame: Identifiable, Hashable, Equatable, Sendable {
    public var id: UUID
    public var assetCatalog: CutAssetCatalog

    public init(id: UUID = UUID(), assetCatalog: CutAssetCatalog = CutAssetCatalog()) {
        self.id = id
        self.assetCatalog = assetCatalog
    }
}

public struct CutWorkspaceFramePresentationRestoreResult: Hashable, Equatable, Sendable {
    public var frameID: UUID
    public var needsArtworkLoad: Bool
    public var restoredCachedCanvas: Bool

    public init(
        frameID: UUID,
        needsArtworkLoad: Bool,
        restoredCachedCanvas: Bool
    ) {
        self.frameID = frameID
        self.needsArtworkLoad = needsArtworkLoad
        self.restoredCachedCanvas = restoredCachedCanvas
    }
}

public struct CutWorkspaceFramePresentationState {
    public var frames: [CutWorkspaceFramePresentationFrame]
    public var selectedFrameID: UUID?
    public var selectedFrameIDs: Set<UUID>
    public var selectedFrameSelectionAnchorID: UUID?
    public var lastOpenedFrameID: UUID?
    public var selectedRegionID: UUID?
    public var selectedRegionIDs: Set<UUID>
    public var selectedRegionAnchorID: UUID?
    public var activeArtwork: CutWorkspaceFrameArtworkState
    public var cachedArtworkByFrameID: [UUID: CutWorkspaceFrameArtworkState]
    public var activeCanvasPresentation: CutWorkspaceCanvasPresentationState
    public var cachedCanvasPresentationByFrameID: [UUID: CutWorkspaceCanvasPresentationState]
    public var errorMessage: String?
    public var needsGuideOverlayRefresh: Bool
    public var needsExtractionStateRefresh: Bool

    public init(
        frames: [CutWorkspaceFramePresentationFrame] = [],
        selectedFrameID: UUID? = nil,
        selectedFrameIDs: Set<UUID> = [],
        selectedFrameSelectionAnchorID: UUID? = nil,
        lastOpenedFrameID: UUID? = nil,
        selectedRegionID: UUID? = nil,
        selectedRegionIDs: Set<UUID> = [],
        selectedRegionAnchorID: UUID? = nil,
        activeArtwork: CutWorkspaceFrameArtworkState = CutWorkspaceFrameArtworkState(),
        cachedArtworkByFrameID: [UUID: CutWorkspaceFrameArtworkState] = [:],
        activeCanvasPresentation: CutWorkspaceCanvasPresentationState = CutWorkspaceCanvasPresentationState(),
        cachedCanvasPresentationByFrameID: [UUID: CutWorkspaceCanvasPresentationState] = [:],
        errorMessage: String? = nil,
        needsGuideOverlayRefresh: Bool = false,
        needsExtractionStateRefresh: Bool = false
    ) {
        self.frames = frames
        self.selectedFrameID = selectedFrameID
        self.selectedFrameIDs = selectedFrameIDs
        self.selectedFrameSelectionAnchorID = selectedFrameSelectionAnchorID
        self.lastOpenedFrameID = lastOpenedFrameID
        self.selectedRegionID = selectedRegionID
        self.selectedRegionIDs = selectedRegionIDs
        self.selectedRegionAnchorID = selectedRegionAnchorID
        self.activeArtwork = activeArtwork
        self.cachedArtworkByFrameID = cachedArtworkByFrameID
        self.activeCanvasPresentation = activeCanvasPresentation
        self.cachedCanvasPresentationByFrameID = cachedCanvasPresentationByFrameID
        self.errorMessage = errorMessage
        self.needsGuideOverlayRefresh = needsGuideOverlayRefresh
        self.needsExtractionStateRefresh = needsExtractionStateRefresh
    }

    public var orderedFrameIDs: [UUID] {
        frames.map(\.id)
    }

    public var resolvedSelectedFrameID: UUID? {
        let availableFrameIDs = Set(orderedFrameIDs)
        if let selectedFrameID, availableFrameIDs.contains(selectedFrameID) {
            return selectedFrameID
        }
        if let lastOpenedFrameID, availableFrameIDs.contains(lastOpenedFrameID) {
            return lastOpenedFrameID
        }
        return frames.first?.id
    }
}

public enum CutWorkspaceFramePresentationCoordinator {
    public static func prepareForFramePresentationTransition(
        in state: inout CutWorkspaceFramePresentationState
    ) {
        guard let frameID = state.resolvedSelectedFrameID else { return }
        state.cachedArtworkByFrameID[frameID] = state.activeArtwork
        cacheActiveCanvasPresentationState(in: &state)
    }

    @discardableResult
    public static func transitionFrameSelection(
        to primaryFrameID: UUID,
        in state: inout CutWorkspaceFramePresentationState
    ) -> CutWorkspaceFramePresentationRestoreResult? {
        guard state.orderedFrameIDs.contains(primaryFrameID) else { return nil }
        let currentPrimaryFrameID = state.resolvedSelectedFrameID
        guard currentPrimaryFrameID != primaryFrameID else { return nil }

        if currentPrimaryFrameID != nil {
            prepareForFramePresentationTransition(in: &state)
        }

        state.selectedFrameID = primaryFrameID
        state.lastOpenedFrameID = primaryFrameID
        return restoreFramePresentationState(for: primaryFrameID, in: &state)
    }

    @discardableResult
    public static func activateNewFrame(
        _ frameID: UUID,
        in state: inout CutWorkspaceFramePresentationState
    ) -> CutWorkspaceFramePresentationRestoreResult? {
        guard state.orderedFrameIDs.contains(frameID) else { return nil }
        seedFramePresentationState(for: frameID, in: &state)
        state.selectedFrameID = frameID
        state.selectedFrameIDs = [frameID]
        state.selectedFrameSelectionAnchorID = frameID
        state.lastOpenedFrameID = frameID
        return restoreFramePresentationState(for: frameID, in: &state)
    }

    @discardableResult
    public static func restoreFramePresentationState(
        for frameID: UUID,
        in state: inout CutWorkspaceFramePresentationState
    ) -> CutWorkspaceFramePresentationRestoreResult? {
        guard let frame = state.frames.first(where: { $0.id == frameID }) else { return nil }

        let cachedArtwork = state.cachedArtworkByFrameID[frameID]
        state.activeArtwork = cachedArtwork ?? CutWorkspaceFrameArtworkState()
        state.selectedRegionID = nil
        state.selectedRegionIDs = []
        state.selectedRegionAnchorID = nil

        let cachedCanvas = state.cachedCanvasPresentationByFrameID[frameID]
        state.activeCanvasPresentation = cachedCanvas ?? CutWorkspaceCanvasPresentationState()
        state.errorMessage = nil
        state.needsExtractionStateRefresh = true

        let needsArtworkLoad = requiresArtworkLoad(
            for: frame,
            cachedArtwork: cachedArtwork
        )
        let restoredCachedCanvas = cachedCanvas != nil
        if restoredCachedCanvas == false && needsArtworkLoad == false {
            state.needsGuideOverlayRefresh = true
        }

        return CutWorkspaceFramePresentationRestoreResult(
            frameID: frameID,
            needsArtworkLoad: needsArtworkLoad,
            restoredCachedCanvas: restoredCachedCanvas
        )
    }

    public static func seedFramePresentationState(
        for frameID: UUID,
        in state: inout CutWorkspaceFramePresentationState
    ) {
        guard state.orderedFrameIDs.contains(frameID) else { return }
        if state.cachedArtworkByFrameID[frameID] == nil {
            state.cachedArtworkByFrameID[frameID] = state.activeArtwork
        }
        if state.cachedCanvasPresentationByFrameID[frameID] == nil {
            state.cachedCanvasPresentationByFrameID[frameID] = CutWorkspaceCanvasPresentationState()
        }
    }

    public static func cacheActiveCanvasPresentationState(
        in state: inout CutWorkspaceFramePresentationState
    ) {
        guard let frameID = state.resolvedSelectedFrameID else { return }
        var cachedCanvas = state.activeCanvasPresentation
        if state.selectedRegionID != nil {
            cachedCanvas.overlayImage = nil
        }
        state.cachedCanvasPresentationByFrameID[frameID] = cachedCanvas
    }

    public static func applyCanvasPresentationState(
        _ canvasPresentationState: CutWorkspaceCanvasPresentationState?,
        in state: inout CutWorkspaceFramePresentationState
    ) {
        state.activeCanvasPresentation = canvasPresentationState ?? CutWorkspaceCanvasPresentationState()
    }

    public static func resetAllCachedCanvasPresentationStates(
        in state: inout CutWorkspaceFramePresentationState
    ) {
        let layerVisibility = state.activeCanvasPresentation.layerVisibility
        state.cachedCanvasPresentationByFrameID = [:]
        state.activeCanvasPresentation = CutWorkspaceCanvasPresentationState(
            layerVisibility: layerVisibility
        )
        state.needsGuideOverlayRefresh = true
    }

    public static func invalidateCachedCanvasPresentationStates<S: Sequence>(
        for frameIDs: S,
        in state: inout CutWorkspaceFramePresentationState
    ) where S.Element == UUID {
        for frameID in frameIDs {
            state.cachedCanvasPresentationByFrameID.removeValue(forKey: frameID)
        }
    }

    public static func resetFramePresentationState(
        in state: inout CutWorkspaceFramePresentationState
    ) {
        state.selectedRegionID = nil
        state.selectedRegionIDs = []
        state.selectedRegionAnchorID = nil
        resetAllCachedCanvasPresentationStates(in: &state)
        state.errorMessage = nil
    }

    private static func requiresArtworkLoad(
        for frame: CutWorkspaceFramePresentationFrame,
        cachedArtwork: CutWorkspaceFrameArtworkState?
    ) -> Bool {
        CutAssetKind.allCases.contains { kind in
            frame.assetCatalog[kind] != nil && cachedArtwork?[kind] == nil
        }
    }
}
