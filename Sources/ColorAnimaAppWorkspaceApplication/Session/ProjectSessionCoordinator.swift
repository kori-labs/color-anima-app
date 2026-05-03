import Foundation

// MARK: - Error

public enum ProjectSessionCoordinatorError: LocalizedError, Equatable {
    case missingProjectDirectory
    case cutNotFound(UUID)
    case frameNotFound(UUID)

    public var errorDescription: String? {
        switch self {
        case .missingProjectDirectory:
            "Save the project to a folder before running this action."
        case let .cutNotFound(id):
            "Cut \(id.uuidString) could not be found in the project tree."
        case let .frameNotFound(id):
            "Frame \(id.uuidString) could not be found in the active cut."
        }
    }
}

// MARK: - Session document identity

/// Minimal snapshot of the project document that the session coordinator needs
/// to build tree nodes and route dirty/save requests — contains no kernel types.
public struct ProjectSessionDocumentSnapshot: Hashable, Equatable, Sendable {
    public var projectID: UUID
    public var projectName: String
    public var rootNode: WorkspaceProjectTreeNode
    public var colorSystemGroups: [ColorSystemGroup]
    public var activeStatusName: String
    public var selectedGroupID: UUID?
    public var selectedSubsetID: UUID?
    public var lastOpenedCutID: UUID?

    public init(
        projectID: UUID,
        projectName: String,
        rootNode: WorkspaceProjectTreeNode,
        colorSystemGroups: [ColorSystemGroup] = [],
        activeStatusName: String = "default",
        selectedGroupID: UUID? = nil,
        selectedSubsetID: UUID? = nil,
        lastOpenedCutID: UUID? = nil
    ) {
        self.projectID = projectID
        self.projectName = projectName
        self.rootNode = rootNode
        self.colorSystemGroups = colorSystemGroups
        self.activeStatusName = activeStatusName
        self.selectedGroupID = selectedGroupID
        self.selectedSubsetID = selectedSubsetID
        self.lastOpenedCutID = lastOpenedCutID
    }
}

// MARK: - Export action request

/// Opaque export request produced by the coordinator; fulfilled by a downstream
/// export service that has access to cut workspace data. Parameters beyond
/// cutID are expanded by whichever layer resolves the request.
public struct ProjectSessionExportRequest: Hashable, Equatable, Sendable {
    public var cutID: UUID

    public init(cutID: UUID) {
        self.cutID = cutID
    }
}

// MARK: - Session state

public struct ProjectSessionState: Equatable, Sendable {
    public var document: ProjectSessionDocumentSnapshot
    public var selectedNodeID: UUID?
    public var selectedNodeIDs: Set<UUID>
    public var selectionAnchorNodeID: UUID?
    public var activeCutID: UUID?
    public var pendingCloseRequest: WorkspacePendingCloseRequest?
    public var dirtyCutIDs: Set<UUID>
    public var metadataDirty: Bool

    /// Monotonic generation counter incremented whenever a new bounded
    /// re-propagation pass begins. Callers may snapshot this and compare on
    /// completion to detect superseded results.
    public var regionRewriteGeneration: Int

    /// Feedback string from the most recent scoped region update pass.
    /// `nil` until a pass completes successfully.
    public var partialRePropagationFeedback: String?

    public var hasUnsavedChanges: Bool {
        metadataDirty || dirtyCutIDs.isEmpty == false
    }

    public var orderedDirtyCutIDs: [UUID] {
        dirtyCutIDs.sorted { $0.uuidString < $1.uuidString }
    }

    public init(
        document: ProjectSessionDocumentSnapshot,
        selectedNodeID: UUID? = nil,
        selectedNodeIDs: Set<UUID> = [],
        selectionAnchorNodeID: UUID? = nil,
        activeCutID: UUID? = nil,
        pendingCloseRequest: WorkspacePendingCloseRequest? = nil,
        dirtyCutIDs: Set<UUID> = [],
        metadataDirty: Bool = false,
        regionRewriteGeneration: Int = 0,
        partialRePropagationFeedback: String? = nil
    ) {
        self.document = document
        self.selectedNodeID = selectedNodeID
        self.selectedNodeIDs = selectedNodeIDs
        self.selectionAnchorNodeID = selectionAnchorNodeID
        self.activeCutID = activeCutID
        self.pendingCloseRequest = pendingCloseRequest
        self.dirtyCutIDs = dirtyCutIDs
        self.metadataDirty = metadataDirty
        self.regionRewriteGeneration = regionRewriteGeneration
        self.partialRePropagationFeedback = partialRePropagationFeedback
    }
}

// MARK: - Session coordinator

public enum ProjectSessionCoordinator {

    // MARK: Initialisation

    /// Build initial session state from a document snapshot, mirroring
    /// `ProjectSessionModel.init` selection bootstrap logic.
    public static func makeInitialState(
        document: ProjectSessionDocumentSnapshot
    ) -> ProjectSessionState {
        var state = ProjectSessionState(document: document)

        let initialCutID = document.lastOpenedCutID
            ?? firstCutID(in: document.rootNode)

        if let cutID = initialCutID {
            var treeState = treeSelectionState(from: state)
            ProjectTreeSelectionCoordinator.selectNode(cutID, in: &treeState)
            applyTreeSelection(treeState, to: &state)
        } else {
            state.selectedNodeID = document.projectID
            state.selectedNodeIDs = [document.projectID]
            state.selectionAnchorNodeID = document.projectID
            state.activeCutID = nil
        }

        return state
    }

    // MARK: Dirty tracking

    public static func markDirty(
        cutID: UUID,
        in state: inout ProjectSessionState
    ) {
        state.dirtyCutIDs.insert(cutID)
    }

    public static func markCutSaved(
        cutID: UUID,
        in state: inout ProjectSessionState
    ) {
        state.dirtyCutIDs.remove(cutID)
    }

    public static func markMetadataSaved(in state: inout ProjectSessionState) {
        state.metadataDirty = false
    }

    public static func markMetadataDirty(in state: inout ProjectSessionState) {
        state.metadataDirty = true
    }

    // MARK: Pending close request

    /// Returns `true` when the project can close immediately (no unsaved changes).
    /// Returns `false` and populates `pendingCloseRequest` when there are dirty cuts.
    @discardableResult
    public static func requestClose(
        in state: inout ProjectSessionState
    ) -> Bool {
        guard state.hasUnsavedChanges else { return true }
        state.pendingCloseRequest = WorkspacePendingCloseRequest(
            dirtyCutIDs: state.orderedDirtyCutIDs
        )
        return false
    }

    public static func dismissCloseRequest(in state: inout ProjectSessionState) {
        state.pendingCloseRequest = nil
    }

    // MARK: Node selection (delegate to ProjectTreeSelectionCoordinator)

    public static func selectNode(
        _ nodeID: UUID,
        modifiers: WorkspaceSelectionModifiers = [],
        in state: inout ProjectSessionState
    ) {
        var treeState = treeSelectionState(from: state)
        ProjectTreeSelectionCoordinator.selectNode(nodeID, modifiers: modifiers, in: &treeState)
        applyTreeSelection(treeState, to: &state)
    }

    // MARK: Partial re-propagation feedback

    public static func incrementRegionRewriteGeneration(
        in state: inout ProjectSessionState
    ) -> Int {
        state.regionRewriteGeneration += 1
        return state.regionRewriteGeneration
    }

    public static func applyPartialRePropagationFeedback(
        _ feedback: String,
        generation: Int,
        in state: inout ProjectSessionState
    ) {
        guard generation == state.regionRewriteGeneration else { return }
        state.partialRePropagationFeedback = feedback
    }

    // MARK: Document update

    /// Replace the document snapshot (e.g. after a rename or tree restructure).
    /// Preserves selection by re-normalizing through the new tree.
    public static func updateDocument(
        _ document: ProjectSessionDocumentSnapshot,
        in state: inout ProjectSessionState
    ) {
        state.document = document
        var treeState = treeSelectionState(from: state)
        ProjectTreeSelectionCoordinator.normalizeSelectionAfterStructureChange(in: &treeState)
        applyTreeSelection(treeState, to: &state)
    }

    // MARK: Export action surface
    // access and per-frame asset loading via the kernel bridge. The export
    // request is surfaced here as a typed value; the actual export execution

    public static func makeExportRequest(
        for cutID: UUID,
        in state: ProjectSessionState
    ) -> Result<ProjectSessionExportRequest, ProjectSessionCoordinatorError> {
        guard ProjectTreeSelectionCoordinator.selectionKind(
            for: cutID,
            in: state.document.rootNode
        ) == .cut else {
            return .failure(.cutNotFound(cutID))
        }
        return .success(ProjectSessionExportRequest(cutID: cutID))
    }

    // MARK: Private helpers

    private static func treeSelectionState(
        from state: ProjectSessionState
    ) -> ProjectTreeSelectionState {
        ProjectTreeSelectionState(
            rootNode: state.document.rootNode,
            selectedNodeID: state.selectedNodeID,
            selectedNodeIDs: state.selectedNodeIDs,
            selectionAnchorNodeID: state.selectionAnchorNodeID,
            activeCutID: state.activeCutID,
            lastOpenedCutID: state.document.lastOpenedCutID,
            dirtyCutIDs: state.dirtyCutIDs
        )
    }

    private static func applyTreeSelection(
        _ treeState: ProjectTreeSelectionState,
        to state: inout ProjectSessionState
    ) {
        state.selectedNodeID = treeState.selectedNodeID
        state.selectedNodeIDs = treeState.selectedNodeIDs
        state.selectionAnchorNodeID = treeState.selectionAnchorNodeID
        state.activeCutID = treeState.activeCutID
    }

    private static func firstCutID(in node: WorkspaceProjectTreeNode) -> UUID? {
        if node.kind == .cut { return node.id }
        for child in node.children {
            if let id = firstCutID(in: child) { return id }
        }
        return nil
    }
}
