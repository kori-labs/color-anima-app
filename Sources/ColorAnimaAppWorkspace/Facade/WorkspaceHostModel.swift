import ColorAnimaAppEngine
import ColorAnimaAppWorkspaceApplication
import ColorAnimaAppWorkspaceCutEditor
import CoreGraphics
import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class WorkspaceHostModel {

    // MARK: - Primary stored state

    var session: ProjectSessionState

    // MARK: - Transient UI state

    var errorMessage: String?
    var isRegionDebugOverlayEnabled = false
    var isExtractingRegions = false
    var isTrackingRunning = false
    var trackingSummaryLabel: String?
    var layerVisibility = LayerVisibility()
    var extractionFeedback: LongRunningActionFeedback?

    init(session: ProjectSessionState = WorkspaceHostModel.initialSession()) {
        self.session = session
    }

    // MARK: - Tree projections

    var treeRoot: WorkspaceProjectTreeNode {
        session.document.rootNode
    }

    var selectedNodeID: UUID? {
        session.selectedNodeID
    }

    var selectedNodeIDs: Set<UUID> {
        session.selectedNodeIDs
    }

    var selectionAnchorNodeID: UUID? {
        session.selectionAnchorNodeID
    }

    var selectedNode: WorkspaceProjectTreeNode? {
        guard let selectedNodeID else { return nil }
        return ProjectTreeSelectionCoordinator.findNode(id: selectedNodeID, in: treeRoot)
    }

    var activeCutID: UUID? {
        session.activeCutID
    }

    var dirtyCutIDs: Set<UUID> {
        session.dirtyCutIDs
    }

    var hasUnsavedChanges: Bool {
        session.hasUnsavedChanges
    }

    var pendingCloseRequest: WorkspacePendingCloseRequest? {
        session.pendingCloseRequest
    }

    // MARK: - Navigation labels

    var projectName: String {
        session.document.projectName
    }

    var sequenceName: String {
        name(for: .sequence)
    }

    var sceneName: String {
        name(for: .scene)
    }

    var cutName: String {
        name(for: .cut)
    }

    var currentFrameName: String {
        "#001"
    }

    var projectCanvasResolution: ProjectCanvasResolution {
        ProjectCanvasResolution(width: 1920, height: 1080)
    }

    // MARK: - Command bar projections

    var canExportPreview: Bool {
        activeCutID != nil
    }

    var isTrackingRunnable: Bool {
        activeCutID != nil && isTrackingRunning == false
    }

    var hasTrackingResults: Bool {
        trackingSummaryLabel != nil
    }

    var trackingCutSummaryLabel: String? {
        trackingSummaryLabel
    }

    var trackingCancelSummaryLabel: String? {
        isTrackingRunning ? "Tracking running" : nil
    }

    var trackingReadinessReason: String? {
        activeCutID == nil ? "Select a cut before tracking." : nil
    }

    var extractionProgressLabel: String? {
        extractionFeedback?.progressText
    }

    var activeActionFeedback: LongRunningActionFeedback? {
        ActiveActionFeedbackSelector.select(from: [extractionFeedback].compactMap { $0 })
    }

    // MARK: - Cut workspace projections

    var activeCutWorkspace: WorkspaceHostActiveCutState? {
        guard let activeCutID else { return nil }
        return WorkspaceHostActiveCutState(
            cutID: activeCutID,
            selectedFrameID: selectedFrameIDs.first,
            selectedRegionIDs: [],
            selectedRegionAnchorID: nil,
            regions: regions,
            imageSize: CGSize(
                width: projectCanvasResolution.width,
                height: projectCanvasResolution.height
            )
        )
    }

    var canvasPresentation: CutWorkspaceCanvasPresentation? {
        CutWorkspaceCanvasPresentationCoordinator.makePresentation(
            from: CutWorkspaceCanvasPresentationState(layerVisibility: layerVisibility),
            isRegionDebugOverlayEnabled: isRegionDebugOverlayEnabled
        )
    }

    var regions: [CanvasSelectionRegion] {
        []
    }

    var selectedRegion: CanvasSelectionRegion? {
        nil
    }

    var selectedRegionInspectorState: SelectedRegionInspectorState? {
        nil
    }

    var regionsSummary: WorkspaceHostRegionsSummary? {
        guard regions.isEmpty == false else { return nil }
        return WorkspaceHostRegionsSummary(rows: [])
    }

    var isMultiRegionSelect: Bool {
        false
    }

    var outlineArtwork: ImportedArtwork? {
        nil
    }

    var highlightLineArtwork: ImportedArtwork? {
        nil
    }

    var shadowLineArtwork: ImportedArtwork? {
        nil
    }

    var extractionStatus: WorkspaceHostExtractionStatus {
        if isExtractingRegions { return .running }
        if regions.isEmpty == false { return .done }
        return .idle
    }

    var extractionActionTitle: String {
        isExtractingRegions ? "Extracting" : "Extract Regions"
    }

    var canTriggerExtraction: Bool {
        activeCutID != nil && isExtractingRegions == false
    }

    // MARK: - Frame strip projections

    var frameStripItems: [FrameStripCardItem] {
        FrameStripProjection.cardItems(from: Self.trackingFrames.map { frame in
            FrameStripProjectionInput(
                id: frame.frameID,
                orderIndex: frame.orderIndex,
                isCurrent: frame.orderIndex == 0,
                isSelected: frame.orderIndex == 0,
                isIncludedReference: frame.isKeyFrame,
                isActiveReference: frame.isKeyFrame,
                hasExtractedRegions: false
            )
        })
    }

    var frameStripItemIDs: [UUID] {
        Self.trackingFrames.map(\.frameID)
    }

    var selectedFrameIDs: Set<UUID> {
        [Self.trackingFrames[0].frameID]
    }

    var canDeleteSelectedFrames: Bool {
        false
    }

    var deleteSelectedFramesTitle: String {
        "Delete Selected Frames"
    }

    // MARK: - Inspector projections

    var trackingQueuePresentation: TrackingQueueNavigatorPresentation? {
        nil
    }

    var confidenceFrameRows: [FrameConfidenceRow] {
        []
    }

    var groups: [ColorSystemGroup] {
        session.document.colorSystemGroups
    }

    var selectedGroupID: UUID? {
        session.document.selectedGroupID
    }

    var selectedSubsetID: UUID? {
        session.document.selectedSubsetID
    }

    var selectedGroupIndex: Int? {
        guard let selectedGroupID else { return nil }
        return groups.firstIndex { $0.id == selectedGroupID }
    }

    var activeStatusName: String {
        session.document.activeStatusName
    }

    var selectedStatusNames: Set<String> {
        Set(selectedSubset?.palettes.map(\.name) ?? [])
    }

    var colorRuleSet: ColorRuleSet {
        .empty
    }

    var renderSettings: RenderSettingsModel {
        .default
    }

    // MARK: - Tree actions

    func selectNode(_ nodeID: UUID, modifiers: WorkspaceSelectionModifiers = []) {
        ProjectSessionCoordinator.selectNode(nodeID, modifiers: modifiers, in: &session)
    }

    func createSequence() {
        let node = WorkspaceProjectTreeNode(
            id: UUID(),
            kind: .sequence,
            name: numberedName(prefix: "Sequence", existing: treeRoot.children)
        )
        updateRoot { root in
            root.children.append(node)
        }
        selectNode(node.id)
    }

    func createScene(in sequenceID: UUID? = nil) {
        guard let parentID = sequenceID ?? selectedPath.last(where: { $0.kind == .sequence })?.id else {
            return
        }
        var createdID: UUID?
        updateRoot { root in
            appendChild(
                WorkspaceProjectTreeNode(id: UUID(), kind: .scene, name: "Scene 01"),
                to: parentID,
                in: &root,
                createdID: &createdID
            )
        }
        if let createdID {
            selectNode(createdID)
        }
    }

    func createCut(in sceneID: UUID? = nil) {
        guard let parentID = sceneID ?? selectedPath.last(where: { $0.kind == .scene })?.id else {
            return
        }
        var createdID: UUID?
        updateRoot { root in
            appendChild(
                WorkspaceProjectTreeNode(id: UUID(), kind: .cut, name: "Cut 001"),
                to: parentID,
                in: &root,
                createdID: &createdID
            )
        }
        if let createdID {
            selectNode(createdID)
        }
    }

    func renameNode(_ nodeID: UUID, to name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedName.isEmpty == false else { return }
        updateRoot { root in
            rename(nodeID: nodeID, name: trimmedName, in: &root)
        }
    }

    func deleteNode(_ nodeID: UUID) {
        guard nodeID != treeRoot.id else { return }
        updateRoot { root in
            remove(nodeID: nodeID, from: &root)
        }
    }

    func moveTreeNodes(_ nodeIDs: Set<UUID>, to targetNodeID: UUID, position: WorkspaceDropPosition) {
        guard nodeIDs.isEmpty == false, nodeIDs.contains(targetNodeID) == false else { return }
        var movedNodes: [WorkspaceProjectTreeNode] = []
        updateRoot { root in
            movedNodes = remove(nodeIDs: nodeIDs, from: &root)
            guard movedNodes.isEmpty == false else { return }
            insert(movedNodes, to: targetNodeID, position: position, in: &root)
        }
    }

    // MARK: - Project actions

    func newProject() {
        session = Self.initialSession()
        trackingSummaryLabel = nil
        errorMessage = nil
    }

    func openProject() {
        newProject()
    }

    func openProject(at _: URL) throws {
        newProject()
    }

    func createProject(at _: URL) throws {
        newProject()
    }

    func saveProject() {
        ProjectSessionCoordinator.markMetadataSaved(in: &session)
        for cutID in session.dirtyCutIDs {
            ProjectSessionCoordinator.markCutSaved(cutID: cutID, in: &session)
        }
    }

    @discardableResult
    func saveProject(to _: URL) throws -> Bool {
        saveProject()
        return true
    }

    @discardableResult
    func resolvePendingClose(saveChanges: Bool, saveTo url: URL? = nil) throws -> Bool {
        if saveChanges {
            if let url {
                _ = try saveProject(to: url)
            } else {
                saveProject()
            }
        }
        ProjectSessionCoordinator.dismissCloseRequest(in: &session)
        return true
    }

    func requestClose() -> Bool {
        ProjectSessionCoordinator.requestClose(in: &session)
    }

    func exportFrames() {
        guard let activeCutID else { return }
        _ = ProjectSessionCoordinator.makeExportRequest(for: activeCutID, in: session)
    }

    func importAssetSequence(_: CutAssetKind, artworks _: [ImportedArtwork]) throws {}

    func importUnifiedLayers(from _: URL) throws {}

    func importUnifiedLayerSequence(from _: [URL]) throws {}

    func importTriSequence(_: TriSequenceImportPlan) throws {}

    // MARK: - Engine-facing actions

    func runTracking() {
        guard isTrackingRunnable else { return }
        isTrackingRunning = true
        defer { isTrackingRunning = false }

        let client = TrackingClient()
        let report = client.run(
            request: TrackingClientRequest(
                frames: Self.trackingFrames,
                keyFrameIDs: [Self.trackingFrames[0].frameID],
                canvasWidth: projectCanvasResolution.width,
                canvasHeight: projectCanvasResolution.height
            )
        )
        trackingSummaryLabel = client.feedbackMessage(for: report)
    }

    func runTrackingPipeline() {
        runTracking()
    }

    func rerunTrackingPipeline() {
        runTracking()
    }

    func extractRegionsWithFeedback() async {
        guard canTriggerExtraction else { return }
        let feedback = LongRunningActionFeedback(actionLabel: "Extract Regions")
        extractionFeedback = feedback
        isExtractingRegions = true
        feedback.markRunning()
        feedback.markCompleted()
        isExtractingRegions = false
    }

    // MARK: - Frame actions

    func createFrame() {}

    func deleteSelectedFrames() {}

    func selectFrame(_ frameID: UUID, modifiers _: WorkspaceSelectionModifiers = []) {
        guard Self.trackingFrames.contains(where: { $0.frameID == frameID }) else { return }
    }

    func selectPreviousFrame() {}

    func selectNextFrame() {}

    func toggleFramePlayback() {}

    func moveSelectedFrames(to _: WorkspaceFrameDropTarget) {}

    func addReferenceFrame(_: UUID) {}

    func setActiveReferenceFrame(_: UUID) {}

    func removeReferenceFrame(_: UUID) {}

    // MARK: - Region actions

    func selectRegion(_: UUID?) {}

    func selectRegion(at point: CGPoint?) {
        guard let point else {
            selectRegion(nil)
            return
        }
        selectRegion(activeCutWorkspace?.region(at: point)?.id)
    }

    func selectRegionWithModifiers(_: UUID?, modifiers _: WorkspaceSelectionModifiers) {}

    func selectRegionRange(_: Set<UUID>, primaryID _: UUID) {}

    func assignRegion(regionID _: UUID, toSubsetID _: UUID) {}

    func assignSelectedRegionToSelectedSubset() {}

    func batchAssignSelectedRegionsToSubset(_: UUID) {}

    func clearSelectedRegionAssignment() {}

    func deleteSelectedRegions() {}

    func renameRegion(_: UUID, to _: String) {}

    func toggleSelectedRegionSplitDecision(for _: WorkspaceHostLineRole) {}

    // MARK: - Tracking queue actions

    func navigateToQueueItem(at _: Int) {}

    func acceptQueueItem(at _: Int) {}

    func skipQueueItem(at _: Int) {}

    func reassignTrackingQueueItem() {}

    func acceptSelectedRegionTracking(promoteToAnchor _: Bool) {}

    func reassignSelectedRegionTracking(promoteToAnchor _: Bool) {}

    func clearSelectedRegionTracking() {}

    // MARK: - Color system actions

    func selectGroup(_ groupID: UUID) {
        mutateColorSystem { state in
            ProjectColorSystemEditingCoordinator.selectGroup(groupID, in: &state)
        }
    }

    func selectSubset(_ subsetID: UUID) {
        mutateColorSystem { state in
            ProjectColorSystemEditingCoordinator.selectSubset(subsetID, in: &state)
        }
    }

    func addGroup() {
        mutateColorSystem { state in
            _ = ProjectColorSystemEditingCoordinator.addGroup(in: &state)
        }
    }

    func removeGroup(_ groupID: UUID) {
        mutateColorSystem { state in
            ProjectColorSystemEditingCoordinator.removeGroup(groupID, in: &state)
        }
    }

    func renameGroup(_ groupID: UUID, to name: String) {
        mutateColorSystem { state in
            ProjectColorSystemEditingCoordinator.renameGroup(groupID, to: name, in: &state)
        }
    }

    func addSubset() {
        mutateColorSystem { state in
            _ = ProjectColorSystemEditingCoordinator.addSubset(in: &state)
        }
    }

    func removeSubset(_ subsetID: UUID) {
        mutateColorSystem { state in
            ProjectColorSystemEditingCoordinator.removeSubset(subsetID, in: &state)
        }
    }

    func renameSubset(_ subsetID: UUID, to name: String) {
        mutateColorSystem { state in
            ProjectColorSystemEditingCoordinator.renameSubset(subsetID, to: name, in: &state)
        }
    }

    func setActiveStatus(_ statusName: String) {
        mutateColorSystem { state in
            ProjectColorSystemEditingCoordinator.setActiveStatus(statusName, in: &state)
        }
    }

    func addStatus(suggestedName: String?) {
        guard let selectedSubsetID else { return }
        mutateStatus { state in
            _ = ProjectStatusEditingCoordinator.addStatus(
                to: selectedSubsetID,
                suggestedName: suggestedName,
                in: &state
            )
        }
    }

    func renameActiveStatus(to newName: String) {
        guard let selectedSubsetID else { return }
        let oldName = activeStatusName
        mutateStatus { state in
            _ = ProjectStatusEditingCoordinator.renameStatus(
                in: selectedSubsetID,
                from: oldName,
                to: newName,
                in: &state
            )
        }
    }

    func removeActiveStatus() {
        guard let selectedSubsetID,
              let fallback = selectedSubset?.palettes.first(where: { $0.name != activeStatusName })?.name else {
            return
        }
        let statusName = activeStatusName
        mutateStatus { state in
            _ = ProjectStatusEditingCoordinator.removeStatus(
                in: selectedSubsetID,
                named: statusName,
                fallbackStatusName: fallback,
                in: &state
            )
        }
    }

    func colorBinding(role: WritableKeyPath<ColorRoles, RGBAColor>) -> Binding<RGBAColor> {
        Binding(
            get: { [weak self] in
                self?.selectedPalette?.roles[keyPath: role] ?? .clear
            },
            set: { [weak self] newValue in
                self?.mutateColorSystem { state in
                    _ = ProjectColorSystemEditingCoordinator.updateSelectedPaletteRole(
                        role,
                        to: newValue,
                        in: &state
                    )
                }
            }
        )
    }

    func subsetFlagBinding(_ keyPath: WritableKeyPath<ColorSystemSubset, Bool>) -> Binding<Bool> {
        Binding(
            get: { [weak self] in
                self?.selectedSubset?[keyPath: keyPath] ?? false
            },
            set: { [weak self] newValue in
                self?.mutateColorSystem { state in
                    _ = ProjectColorSystemEditingCoordinator.updateSelectedSubsetFlag(
                        keyPath,
                        to: newValue,
                        in: &state
                    )
                }
            }
        )
    }

    // MARK: - Rule and render settings actions

    func addRule(_: ColorRule) {}

    func removeRule(id _: UUID) {}

    func moveRule(fromOffsets _: IndexSet, toOffset _: Int) {}

    func updateRule(_: ColorRule) {}

    func triggerWhatIfPreview(ruleID _: UUID, simulatedColor _: RGBAColor) {}

    func clearWhatIfPreview() {}

    func updateRenderSettings(_: RenderSettingsModel) {}

    // MARK: - Layer bindings

    func layerVisibilityBinding(_ keyPath: WritableKeyPath<LayerVisibility, Bool>) -> Binding<Bool> {
        Binding(
            get: { [weak self] in
                self?.layerVisibility[keyPath: keyPath] ?? false
            },
            set: { [weak self] newValue in
                self?.layerVisibility[keyPath: keyPath] = newValue
            }
        )
    }

    // MARK: - Private projections

    private var selectedPath: [WorkspaceProjectTreeNode] {
        guard let selectedNodeID else { return [] }
        return ProjectTreeSelectionCoordinator.treeNodePath(for: selectedNodeID, in: treeRoot) ?? []
    }

    private var selectedSubset: ColorSystemSubset? {
        guard let selectedSubsetID else { return nil }
        return groups.lazy.flatMap(\.subsets).first { $0.id == selectedSubsetID }
    }

    private var selectedPalette: StatusPalette? {
        selectedSubset?.palettes.first { $0.name == activeStatusName }
            ?? selectedSubset?.palettes.first
    }

    private func name(for kind: WorkspaceProjectTreeNodeKind) -> String {
        selectedPath.last(where: { $0.kind == kind })?.name ?? fallbackName(for: kind)
    }

    private func fallbackName(for kind: WorkspaceProjectTreeNodeKind) -> String {
        switch kind {
        case .project:
            return projectName
        case .sequence:
            return "Sequence 01"
        case .scene:
            return "Scene 01"
        case .cut:
            return "Cut 001"
        }
    }

    // MARK: - Private mutations

    private func updateRoot(_ mutate: (inout WorkspaceProjectTreeNode) -> Void) {
        var document = session.document
        var root = document.rootNode
        mutate(&root)
        document.rootNode = root
        ProjectSessionCoordinator.updateDocument(document, in: &session)
        ProjectSessionCoordinator.markMetadataDirty(in: &session)
    }

    private func mutateColorSystem(_ mutate: (inout ProjectColorSystemEditingState) -> Void) {
        var state = ProjectColorSystemEditingState(
            groups: session.document.colorSystemGroups,
            selectedGroupID: session.document.selectedGroupID,
            selectedSubsetID: session.document.selectedSubsetID,
            activeStatusName: session.document.activeStatusName,
            metadataDirty: false,
            activeCutID: activeCutID
        )
        mutate(&state)
        applyColorSystemState(state)
    }

    private func mutateStatus(_ mutate: (inout ProjectStatusEditingState) -> Void) {
        var state = ProjectStatusEditingState(
            groups: session.document.colorSystemGroups,
            selectedSubsetID: session.document.selectedSubsetID,
            activeStatusName: session.document.activeStatusName,
            metadataDirty: false
        )
        mutate(&state)
        var colorState = ProjectColorSystemEditingState(
            groups: state.groups,
            selectedGroupID: session.document.selectedGroupID,
            selectedSubsetID: state.selectedSubsetID,
            activeStatusName: state.activeStatusName,
            metadataDirty: state.metadataDirty,
            activeCutID: activeCutID
        )
        ProjectColorSystemEditingCoordinator.normalizeColorSelection(in: &colorState)
        applyColorSystemState(colorState)
    }

    private func applyColorSystemState(_ state: ProjectColorSystemEditingState) {
        var document = session.document
        document.colorSystemGroups = state.groups
        document.selectedGroupID = state.selectedGroupID
        document.selectedSubsetID = state.selectedSubsetID
        document.activeStatusName = state.activeStatusName
        ProjectSessionCoordinator.updateDocument(document, in: &session)
        if state.metadataDirty {
            ProjectSessionCoordinator.markMetadataDirty(in: &session)
        }
    }

    private func appendChild(
        _ child: WorkspaceProjectTreeNode,
        to parentID: UUID,
        in node: inout WorkspaceProjectTreeNode,
        createdID: inout UUID?
    ) {
        if node.id == parentID {
            node.children.append(child)
            createdID = child.id
            return
        }
        for index in node.children.indices {
            appendChild(child, to: parentID, in: &node.children[index], createdID: &createdID)
            if createdID != nil { return }
        }
    }

    private func rename(nodeID: UUID, name: String, in node: inout WorkspaceProjectTreeNode) {
        if node.id == nodeID {
            node.name = name
            return
        }
        for index in node.children.indices {
            rename(nodeID: nodeID, name: name, in: &node.children[index])
        }
    }

    @discardableResult
    private func remove(nodeID: UUID, from node: inout WorkspaceProjectTreeNode) -> WorkspaceProjectTreeNode? {
        if let index = node.children.firstIndex(where: { $0.id == nodeID }) {
            return node.children.remove(at: index)
        }
        for index in node.children.indices {
            if let removed = remove(nodeID: nodeID, from: &node.children[index]) {
                return removed
            }
        }
        return nil
    }

    private func remove(nodeIDs: Set<UUID>, from node: inout WorkspaceProjectTreeNode) -> [WorkspaceProjectTreeNode] {
        var removed: [WorkspaceProjectTreeNode] = []
        node.children.removeAll { child in
            guard nodeIDs.contains(child.id) else { return false }
            removed.append(child)
            return true
        }
        for index in node.children.indices {
            removed.append(contentsOf: remove(nodeIDs: nodeIDs, from: &node.children[index]))
        }
        return removed
    }

    private func insert(
        _ nodes: [WorkspaceProjectTreeNode],
        to targetNodeID: UUID,
        position: WorkspaceDropPosition,
        in node: inout WorkspaceProjectTreeNode
    ) {
        if node.id == targetNodeID, position == .append {
            node.children.append(contentsOf: nodes)
            return
        }
        for index in node.children.indices {
            if node.children[index].id == targetNodeID {
                switch position {
                case .before:
                    node.children.insert(contentsOf: nodes, at: index)
                case .after:
                    node.children.insert(contentsOf: nodes, at: index + 1)
                case .append:
                    node.children[index].children.append(contentsOf: nodes)
                }
                return
            }
            insert(nodes, to: targetNodeID, position: position, in: &node.children[index])
        }
    }

    private func numberedName(prefix: String, existing: [WorkspaceProjectTreeNode]) -> String {
        let nextNumber = existing.count + 1
        return "\(prefix) \(String(format: "%02d", nextNumber))"
    }

    // MARK: - Seeds

    private static func initialSession() -> ProjectSessionState {
        ProjectSessionCoordinator.makeInitialState(document: initialDocument())
    }

    private static func initialDocument() -> ProjectSessionDocumentSnapshot {
        let projectID = UUID(uuidString: "10000000-0000-4000-8000-000000000001")!
        let sequenceID = UUID(uuidString: "10000000-0000-4000-8000-000000000002")!
        let sceneID = UUID(uuidString: "10000000-0000-4000-8000-000000000003")!
        let cutID = UUID(uuidString: "10000000-0000-4000-8000-000000000004")!
        let defaultSubsetID = UUID(uuidString: "10000000-0000-4000-8000-000000000005")!
        let defaultGroupID = UUID(uuidString: "10000000-0000-4000-8000-000000000006")!
        let defaultGroups = [
            ColorSystemGroup(
                id: defaultGroupID,
                name: "group_1",
                subsets: [
                    ColorSystemSubset(
                        id: defaultSubsetID,
                        name: "subset_1",
                        palettes: [StatusPalette(name: "default", roles: .neutral)]
                    ),
                ]
            ),
        ]

        return ProjectSessionDocumentSnapshot(
            projectID: projectID,
            projectName: "Color Anima Workspace",
            rootNode: WorkspaceProjectTreeNode(
                id: projectID,
                kind: .project,
                name: "Color Anima Workspace",
                children: [
                    WorkspaceProjectTreeNode(
                        id: sequenceID,
                        kind: .sequence,
                        name: "Sequence 01",
                        children: [
                            WorkspaceProjectTreeNode(
                                id: sceneID,
                                kind: .scene,
                                name: "Scene 01",
                                children: [
                                    WorkspaceProjectTreeNode(
                                        id: cutID,
                                        kind: .cut,
                                        name: "Cut 001"
                                    ),
                                ]
                            ),
                        ]
                    ),
                ]
            ),
            colorSystemGroups: defaultGroups,
            activeStatusName: "default",
            selectedGroupID: defaultGroupID,
            selectedSubsetID: defaultSubsetID,
            lastOpenedCutID: cutID
        )
    }

    private static var trackingFrames: [TrackingClientFrameInput] {
        [
            TrackingClientFrameInput(
                frameID: UUID(uuidString: "10000000-0000-4000-8000-000000000101")!,
                orderIndex: 0,
                isKeyFrame: true
            ),
            TrackingClientFrameInput(
                frameID: UUID(uuidString: "10000000-0000-4000-8000-000000000102")!,
                orderIndex: 1,
                isKeyFrame: false
            ),
            TrackingClientFrameInput(
                frameID: UUID(uuidString: "10000000-0000-4000-8000-000000000103")!,
                orderIndex: 2,
                isKeyFrame: false
            ),
        ]
    }
}

struct WorkspaceHostActiveCutState: Equatable {
    var cutID: UUID
    var selectedFrameID: UUID?
    var selectedRegionIDs: Set<UUID>
    var selectedRegionAnchorID: UUID?
    var regions: [CanvasSelectionRegion]
    var imageSize: CGSize

    func region(at imagePoint: CGPoint) -> CanvasSelectionRegion? {
        CutWorkspaceRegionHitTesting.region(
            at: imagePoint,
            imageSize: imageSize,
            in: regions
        )
    }
}

struct WorkspaceHostRegionsSummary: Equatable {
    var rows: [WorkspaceHostRegionListRow]

    var totalRegionCount: Int {
        rows.count
    }

    var assignedRegionCount: Int {
        rows.filter(\.isAssigned).count
    }

    var unassignedRegionCount: Int {
        totalRegionCount - assignedRegionCount
    }
}

struct WorkspaceHostRegionListRow: Identifiable, Equatable {
    var id: UUID
    var displayName: String
    var assignment: RegionListAssignment?
    var isSelected: Bool

    var isAssigned: Bool {
        assignment != nil
    }
}

enum WorkspaceHostExtractionStatus: Equatable {
    case idle
    case running
    case done
}

enum WorkspaceHostLineRole: Equatable {
    case highlight
    case shadow
}
