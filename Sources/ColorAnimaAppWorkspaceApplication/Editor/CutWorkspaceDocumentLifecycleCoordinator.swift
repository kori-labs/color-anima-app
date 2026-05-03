import Foundation

public struct CutWorkspaceDocumentSnapshot: Hashable, Equatable, Sendable {
    public var frames: [CutWorkspaceFrameWorkflowFrame]
    public var layerVisibility: LayerVisibility
    public var lastOpenedFrameID: UUID?

    public init(
        frames: [CutWorkspaceFrameWorkflowFrame] = [],
        layerVisibility: LayerVisibility = LayerVisibility(),
        lastOpenedFrameID: UUID? = nil
    ) {
        self.frames = frames
        self.layerVisibility = layerVisibility
        self.lastOpenedFrameID = lastOpenedFrameID
        CutWorkspaceDocumentLifecycleCoordinator.normalizeDocumentSnapshot(&self)
    }

    public var orderedFrames: [CutWorkspaceFrameWorkflowFrame] {
        CutWorkspaceFrameWorkflowCoordinator.orderedFrames(frames)
    }

    public var resolvedLastOpenedFrameID: UUID? {
        let orderedIDs = orderedFrames.map(\.id)
        if let lastOpenedFrameID, orderedIDs.contains(lastOpenedFrameID) {
            return lastOpenedFrameID
        }
        return orderedIDs.first
    }
}

public struct CutWorkspaceDocumentLifecycleState: Hashable, Equatable, Sendable {
    public var document: CutWorkspaceDocumentSnapshot
    public var selectedFrameID: UUID?
    public var selectedFrameIDs: Set<UUID>
    public var selectedFrameSelectionAnchorID: UUID?
    public var selectedRegionID: UUID?
    public var selectedRegionIDs: Set<UUID>
    public var selectedRegionAnchorID: UUID?
    public var isDirty: Bool
    public var isFramePlaybackActive: Bool
    public var errorMessage: String?
    public var needsArtworkCacheReset: Bool
    public var needsCanvasPresentationCacheReset: Bool
    public var needsCanvasPresentationReset: Bool
    public var needsExtractionStateRefresh: Bool

    public init(
        document: CutWorkspaceDocumentSnapshot = CutWorkspaceDocumentSnapshot(),
        selectedFrameID: UUID? = nil,
        selectedFrameIDs: Set<UUID> = [],
        selectedFrameSelectionAnchorID: UUID? = nil,
        selectedRegionID: UUID? = nil,
        selectedRegionIDs: Set<UUID> = [],
        selectedRegionAnchorID: UUID? = nil,
        isDirty: Bool = false,
        isFramePlaybackActive: Bool = false,
        errorMessage: String? = nil,
        needsArtworkCacheReset: Bool = false,
        needsCanvasPresentationCacheReset: Bool = false,
        needsCanvasPresentationReset: Bool = false,
        needsExtractionStateRefresh: Bool = false
    ) {
        self.document = document
        self.selectedFrameID = selectedFrameID
        self.selectedFrameIDs = selectedFrameIDs
        self.selectedFrameSelectionAnchorID = selectedFrameSelectionAnchorID
        self.selectedRegionID = selectedRegionID
        self.selectedRegionIDs = selectedRegionIDs
        self.selectedRegionAnchorID = selectedRegionAnchorID
        self.isDirty = isDirty
        self.isFramePlaybackActive = isFramePlaybackActive
        self.errorMessage = errorMessage
        self.needsArtworkCacheReset = needsArtworkCacheReset
        self.needsCanvasPresentationCacheReset = needsCanvasPresentationCacheReset
        self.needsCanvasPresentationReset = needsCanvasPresentationReset
        self.needsExtractionStateRefresh = needsExtractionStateRefresh
    }
}

public enum CutWorkspaceDocumentLifecycleCoordinator {
    public static func makeDocumentSnapshot(
        from document: CutWorkspaceDocumentSnapshot,
        layerVisibility: LayerVisibility,
        selectedFrameID: UUID?
    ) -> CutWorkspaceDocumentSnapshot {
        CutWorkspaceDocumentSnapshot(
            frames: document.frames,
            layerVisibility: layerVisibility,
            lastOpenedFrameID: selectedFrameID
        )
    }

    public static func replaceDocument(
        _ document: CutWorkspaceDocumentSnapshot,
        in state: inout CutWorkspaceDocumentLifecycleState
    ) {
        state.document = document
        let selectedFrameID = document.resolvedLastOpenedFrameID
        state.selectedFrameID = selectedFrameID
        state.selectedFrameIDs = selectedFrameID.map { Set([$0]) } ?? []
        state.selectedFrameSelectionAnchorID = selectedFrameID
        state.selectedRegionID = nil
        state.selectedRegionIDs = []
        state.selectedRegionAnchorID = nil
        state.isDirty = false
        state.isFramePlaybackActive = false
        state.errorMessage = nil
        state.needsArtworkCacheReset = true
        state.needsCanvasPresentationCacheReset = true
        state.needsCanvasPresentationReset = true
        state.needsExtractionStateRefresh = true
    }

    public static func markSaved(
        with document: CutWorkspaceDocumentSnapshot? = nil,
        in state: inout CutWorkspaceDocumentLifecycleState
    ) {
        if let document {
            state.document = document

            let validFrameIDs = Set(document.frames.map(\.id))
            let prunedSelection = state.selectedFrameIDs.intersection(validFrameIDs)

            if prunedSelection.isEmpty {
                state.selectedFrameID = document.resolvedLastOpenedFrameID
                state.selectedFrameIDs = state.selectedFrameID.map { Set([$0]) } ?? []
                state.selectedFrameSelectionAnchorID = state.selectedFrameID
            } else {
                if let currentPrimary = state.selectedFrameID,
                   validFrameIDs.contains(currentPrimary) {
                    state.selectedFrameID = currentPrimary
                } else {
                    state.selectedFrameID = preferredSavedSelectionPrimary(
                        from: prunedSelection,
                        in: document
                    )
                }

                state.selectedFrameIDs = prunedSelection
                if let anchor = state.selectedFrameSelectionAnchorID,
                   validFrameIDs.contains(anchor) {
                    state.selectedFrameSelectionAnchorID = anchor
                } else {
                    state.selectedFrameSelectionAnchorID = state.selectedFrameID
                }
            }
        }

        state.isDirty = false
    }

    public static func normalizeDocumentSnapshot(
        _ document: inout CutWorkspaceDocumentSnapshot
    ) {
        if document.frames.isEmpty {
            document.frames = [
                CutWorkspaceFrameWorkflowFrame(
                    orderIndex: 0,
                    name: CutWorkspaceFrameWorkflowCoordinator.defaultFrameName(for: 1)
                )
            ]
        }

        document.frames = document.orderedFrames.enumerated().map { offset, frame in
            var copy = frame
            copy.orderIndex = offset
            if copy.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                copy.name = CutWorkspaceFrameWorkflowCoordinator.defaultFrameName(for: offset + 1)
            }
            return copy
        }

        if document.resolvedLastOpenedFrameID != document.lastOpenedFrameID {
            document.lastOpenedFrameID = document.resolvedLastOpenedFrameID
        }
    }

    public static func preferredSavedSelectionPrimary(
        from selection: Set<UUID>,
        in document: CutWorkspaceDocumentSnapshot
    ) -> UUID? {
        if let lastOpenedFrameID = document.resolvedLastOpenedFrameID,
           selection.contains(lastOpenedFrameID) {
            return lastOpenedFrameID
        }

        return document.orderedFrames.first(where: { selection.contains($0.id) })?.id
    }
}
