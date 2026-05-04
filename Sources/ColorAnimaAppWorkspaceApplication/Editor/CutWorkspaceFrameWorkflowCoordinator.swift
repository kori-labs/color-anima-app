import Foundation

public struct CutWorkspaceFrameWorkflowFrame: Identifiable, Hashable, Equatable, Sendable {
    public var id: UUID
    public var orderIndex: Int
    public var name: String
    public var assets: CutAssetCatalog

    public init(
        id: UUID = UUID(),
        orderIndex: Int = 0,
        name: String = CutWorkspaceFrameWorkflowCoordinator.defaultFrameName(for: 1),
        assets: CutAssetCatalog = CutAssetCatalog()
    ) {
        self.id = id
        self.orderIndex = orderIndex
        self.name = name
        self.assets = assets
    }
}

public struct CutWorkspaceFrameWorkflowState: Hashable, Equatable, Sendable {
    public var frames: [CutWorkspaceFrameWorkflowFrame]
    public var selectedFrameID: UUID?
    public var selectedFrameIDs: Set<UUID>
    public var selectedFrameSelectionAnchorID: UUID?
    public var lastOpenedFrameID: UUID?
    public var keyFrameIDs: [UUID]
    public var activeReferenceFrameID: UUID?
    public var isDirty: Bool
    public var isFramePlaybackActive: Bool
    public var documentRevision: Int
    public var removedFrameIDs: Set<UUID>
    public var needsFramePresentationPreparation: Bool
    public var framePresentationRestoreFrameID: UUID?
    public var framePresentationSeedFrameID: UUID?

    public init(
        frames: [CutWorkspaceFrameWorkflowFrame] = [],
        selectedFrameID: UUID? = nil,
        selectedFrameIDs: Set<UUID> = [],
        selectedFrameSelectionAnchorID: UUID? = nil,
        lastOpenedFrameID: UUID? = nil,
        keyFrameIDs: [UUID] = [],
        activeReferenceFrameID: UUID? = nil,
        isDirty: Bool = false,
        isFramePlaybackActive: Bool = false,
        documentRevision: Int = 0,
        removedFrameIDs: Set<UUID> = [],
        needsFramePresentationPreparation: Bool = false,
        framePresentationRestoreFrameID: UUID? = nil,
        framePresentationSeedFrameID: UUID? = nil
    ) {
        self.frames = frames
        self.selectedFrameID = selectedFrameID
        self.selectedFrameIDs = selectedFrameIDs
        self.selectedFrameSelectionAnchorID = selectedFrameSelectionAnchorID
        self.lastOpenedFrameID = lastOpenedFrameID
        self.keyFrameIDs = keyFrameIDs
        self.activeReferenceFrameID = activeReferenceFrameID
        self.isDirty = isDirty
        self.isFramePlaybackActive = isFramePlaybackActive
        self.documentRevision = documentRevision
        self.removedFrameIDs = removedFrameIDs
        self.needsFramePresentationPreparation = needsFramePresentationPreparation
        self.framePresentationRestoreFrameID = framePresentationRestoreFrameID
        self.framePresentationSeedFrameID = framePresentationSeedFrameID
        CutWorkspaceFrameWorkflowCoordinator.normalizeFrameState(in: &self)
    }

    public var orderedFrames: [CutWorkspaceFrameWorkflowFrame] {
        CutWorkspaceFrameWorkflowCoordinator.orderedFrames(frames)
    }

    public var orderedFrameIDs: [UUID] {
        orderedFrames.map(\.id)
    }
}

public enum CutWorkspaceFrameWorkflowCoordinator {
    public static func defaultFrameName(for position: Int) -> String {
        CutWorkspaceFrameNormalizer.defaultFrameName(for: position)
    }

    public static func orderedFrames(
        _ frames: [CutWorkspaceFrameWorkflowFrame]
    ) -> [CutWorkspaceFrameWorkflowFrame] {
        CutWorkspaceFrameNormalizer.orderedFrames(frames)
    }

    @discardableResult
    public static func createFrame(
        named name: String? = nil,
        id: UUID = UUID(),
        in state: inout CutWorkspaceFrameWorkflowState
    ) -> CutWorkspaceFrameWorkflowFrame {
        CutWorkspaceFrameMutator.createFrame(named: name, id: id, in: &state)
    }

    @discardableResult
    public static func moveFrames(
        _ frameIDs: [UUID],
        to target: WorkspaceFrameDropTarget,
        in state: inout CutWorkspaceFrameWorkflowState
    ) -> [UUID]? {
        CutWorkspaceFrameMutator.moveFrames(frameIDs, to: target, in: &state)
    }

    @discardableResult
    public static func deleteFrames(
        _ frameIDs: [UUID],
        in state: inout CutWorkspaceFrameWorkflowState
    ) -> UUID? {
        CutWorkspaceFrameMutator.deleteFrames(frameIDs, in: &state)
    }

    public static func setReferenceFrame(
        _ frameID: UUID?,
        in state: inout CutWorkspaceFrameWorkflowState
    ) {
        CutWorkspaceFrameReferenceManager.setReferenceFrame(frameID, in: &state)
    }

    @discardableResult
    public static func addReferenceFrame(
        _ frameID: UUID,
        in state: inout CutWorkspaceFrameWorkflowState
    ) -> Bool {
        CutWorkspaceFrameReferenceManager.addReferenceFrame(frameID, in: &state)
    }

    public static func removeReferenceFrame(
        _ frameID: UUID,
        in state: inout CutWorkspaceFrameWorkflowState
    ) {
        CutWorkspaceFrameReferenceManager.removeReferenceFrame(frameID, in: &state)
    }

    public static func setActiveReferenceFrame(
        _ frameID: UUID?,
        in state: inout CutWorkspaceFrameWorkflowState
    ) {
        CutWorkspaceFrameReferenceManager.setActiveReferenceFrame(frameID, in: &state)
    }

    public static func setLastOpenedFrameID(
        _ frameID: UUID?,
        in state: inout CutWorkspaceFrameWorkflowState
    ) {
        CutWorkspaceFrameNormalizer.setLastOpenedFrameID(frameID, in: &state)
    }

    public static func normalizeFrameState(in state: inout CutWorkspaceFrameWorkflowState) {
        CutWorkspaceFrameNormalizer.normalizeFrameState(in: &state)
    }
}
