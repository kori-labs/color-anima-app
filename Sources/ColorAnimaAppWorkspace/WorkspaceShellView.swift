import ColorAnimaAppEngine
import ColorAnimaAppWorkspaceApplication
import ColorAnimaAppWorkspaceCutEditor
import ColorAnimaAppWorkspaceDesignSystem
import ColorAnimaAppWorkspaceProjectTree
import ColorAnimaAppWorkspaceShell
import SwiftUI

public struct WorkspaceShellView: View {
    private let startupState: WorkspaceState
    private let onRecheck: () -> Void

    @State private var session: ProjectSessionState
    @State private var trackingSummaryLabel: String?

    public init(state: WorkspaceState, onRecheck: @escaping () -> Void) {
        self.startupState = state
        self.onRecheck = onRecheck
        _session = State(initialValue: Self.initialSession())
    }

    public var body: some View {
        VStack(spacing: 0) {
            WorkspaceCommandBarView(
                canExportPreview: session.activeCutID != nil,
                isTrackingRunnable: session.activeCutID != nil,
                hasTrackingResults: trackingSummaryLabel != nil,
                trackingCutSummaryLabel: trackingSummaryLabel,
                extractionProgressLabel: kernelVersionLabel,
                onNewProject: resetWorkspace,
                onOpenProject: resetWorkspace,
                onSaveProject: markSaved,
                onRunTrackingPipeline: runTrackingRoundTrip,
                onRerunTrackingPipeline: runTrackingRoundTrip,
                onExportPreview: {},
                onExportReviewPreview: {},
                onExportPNGSequence: {}
            )

            NavigationSplitView {
                ProjectTreeView(
                    rootNode: session.document.rootNode,
                    selectedNodeID: session.selectedNodeID,
                    selectedNodeIDs: session.selectedNodeIDs,
                    selectionAnchorNodeID: session.selectionAnchorNodeID,
                    selectedNode: selectedNode,
                    onSelectNode: selectNode,
                    onMoveTreeNodes: { _, _, _ in },
                    onRenameNode: renameNode,
                    onCreateSequence: createSequence,
                    onCreateScene: createScene,
                    onCreateCut: createCut,
                    onOpenProjectSettings: onRecheck,
                    onDeleteNode: deleteNode
                )
                .navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 360)
            } detail: {
                cutDetailContent
            }
        }
        .frame(minWidth: 960, minHeight: 640)
        .background(WorkspaceFoundation.Surface.surfaceFill)
    }

    @ViewBuilder
    private var cutDetailContent: some View {
        if selectedNode?.kind == .cut {
            EmptyCutWorkspacePlaceholderView(resolution: cutDetailFallbackResolution)
                .padding(WorkspaceFoundation.Metrics.space5)
        } else {
            WorkspaceSelectionSummaryView(
                selectedNode: selectedNode,
                projectName: name(for: .project),
                sequenceName: name(for: .sequence),
                sceneName: name(for: .scene),
                cutName: name(for: .cut)
            )
        }
    }

    private var cutDetailFallbackResolution: ProjectCanvasResolution {
        ProjectCanvasResolution(width: 1920, height: 1080)
    }

    private var selectedNode: WorkspaceProjectTreeNode? {
        guard let selectedNodeID = session.selectedNodeID else { return nil }
        return ProjectTreeSelectionCoordinator.findNode(
            id: selectedNodeID,
            in: session.document.rootNode
        )
    }

    private var selectedPath: [WorkspaceProjectTreeNode] {
        guard let selectedNodeID = session.selectedNodeID else { return [] }
        return ProjectTreeSelectionCoordinator.treeNodePath(
            for: selectedNodeID,
            in: session.document.rootNode
        ) ?? []
    }

    private var kernelVersionLabel: String? {
        guard let version = startupState.engineStatus.kernelVersion else { return nil }
        return "Kernel v\(version.description)"
    }

    private func name(for kind: WorkspaceProjectTreeNodeKind) -> String {
        selectedPath.last(where: { $0.kind == kind })?.name ?? fallbackName(for: kind)
    }

    private func fallbackName(for kind: WorkspaceProjectTreeNodeKind) -> String {
        switch kind {
        case .project:
            return session.document.projectName
        case .sequence:
            return "Sequence 01"
        case .scene:
            return "Scene 01"
        case .cut:
            return "Cut 001"
        }
    }

    private func selectNode(_ nodeID: UUID, modifiers: WorkspaceSelectionModifiers) {
        ProjectSessionCoordinator.selectNode(nodeID, modifiers: modifiers, in: &session)
    }

    private func resetWorkspace() {
        session = Self.initialSession()
        trackingSummaryLabel = nil
    }

    private func markSaved() {
        ProjectSessionCoordinator.markMetadataSaved(in: &session)
    }

    private func runTrackingRoundTrip() {
        let frames = Self.trackingFrames
        let client = TrackingClient()
        let report = client.run(
            request: TrackingClientRequest(
                frames: frames,
                keyFrameIDs: [frames[0].frameID],
                canvasWidth: 1920,
                canvasHeight: 1080
            )
        )
        trackingSummaryLabel = client.feedbackMessage(for: report)
    }

    private func createSequence() {
        let node = WorkspaceProjectTreeNode(
            id: UUID(),
            kind: .sequence,
            name: numberedName(prefix: "Sequence", existing: session.document.rootNode.children)
        )
        updateRoot { root in
            root.children.append(node)
        }
        selectNode(node.id, modifiers: [])
    }

    private func createScene(parentID: UUID) {
        var createdID: UUID?
        updateRoot { root in
            appendChild(
                WorkspaceProjectTreeNode(
                    id: UUID(),
                    kind: .scene,
                    name: "Scene 01"
                ),
                to: parentID,
                in: &root,
                createdID: &createdID
            )
        }
        if let createdID {
            selectNode(createdID, modifiers: [])
        }
    }

    private func createCut(parentID: UUID) {
        var createdID: UUID?
        updateRoot { root in
            appendChild(
                WorkspaceProjectTreeNode(
                    id: UUID(),
                    kind: .cut,
                    name: "Cut 001"
                ),
                to: parentID,
                in: &root,
                createdID: &createdID
            )
        }
        if let createdID {
            selectNode(createdID, modifiers: [])
        }
    }

    private func renameNode(_ nodeID: UUID, _ name: String) {
        updateRoot { root in
            rename(nodeID: nodeID, name: name, in: &root)
        }
    }

    private func deleteNode(_ nodeID: UUID) {
        guard nodeID != session.document.rootNode.id else { return }
        updateRoot { root in
            remove(nodeID: nodeID, from: &root)
        }
    }

    private func updateRoot(_ mutate: (inout WorkspaceProjectTreeNode) -> Void) {
        var document = session.document
        var root = document.rootNode
        mutate(&root)
        document.rootNode = root
        ProjectSessionCoordinator.updateDocument(document, in: &session)
        ProjectSessionCoordinator.markMetadataDirty(in: &session)
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

    private func remove(nodeID: UUID, from node: inout WorkspaceProjectTreeNode) {
        node.children.removeAll { $0.id == nodeID }
        for index in node.children.indices {
            remove(nodeID: nodeID, from: &node.children[index])
        }
    }

    private func numberedName(prefix: String, existing: [WorkspaceProjectTreeNode]) -> String {
        let nextNumber = existing.count + 1
        return "\(prefix) \(String(format: "%02d", nextNumber))"
    }

    private static func initialSession() -> ProjectSessionState {
        ProjectSessionCoordinator.makeInitialState(document: initialDocument())
    }

    private static func initialDocument() -> ProjectSessionDocumentSnapshot {
        ProjectSessionDocumentSnapshot(
            projectID: WorkspaceShellSeed.projectID,
            projectName: "Color Anima Workspace",
            rootNode: WorkspaceProjectTreeNode(
                id: WorkspaceShellSeed.projectID,
                kind: .project,
                name: "Color Anima Workspace",
                children: [
                    WorkspaceProjectTreeNode(
                        id: WorkspaceShellSeed.sequenceID,
                        kind: .sequence,
                        name: "Sequence 01",
                        children: [
                            WorkspaceProjectTreeNode(
                                id: WorkspaceShellSeed.sceneID,
                                kind: .scene,
                                name: "Scene 01",
                                children: [
                                    WorkspaceProjectTreeNode(
                                        id: WorkspaceShellSeed.cutID,
                                        kind: .cut,
                                        name: "Cut 001"
                                    ),
                                ]
                            ),
                        ]
                    ),
                ]
            ),
            lastOpenedCutID: WorkspaceShellSeed.cutID
        )
    }

    private static var trackingFrames: [TrackingClientFrameInput] {
        [
            TrackingClientFrameInput(
                frameID: WorkspaceShellSeed.frameAID,
                orderIndex: 0,
                isKeyFrame: true
            ),
            TrackingClientFrameInput(
                frameID: WorkspaceShellSeed.frameBID,
                orderIndex: 1,
                isKeyFrame: false
            ),
            TrackingClientFrameInput(
                frameID: WorkspaceShellSeed.frameCID,
                orderIndex: 2,
                isKeyFrame: false
            ),
        ]
    }
}

private enum WorkspaceShellSeed {
    static let projectID = UUID(uuidString: "10000000-0000-4000-8000-000000000001")!
    static let sequenceID = UUID(uuidString: "10000000-0000-4000-8000-000000000002")!
    static let sceneID = UUID(uuidString: "10000000-0000-4000-8000-000000000003")!
    static let cutID = UUID(uuidString: "10000000-0000-4000-8000-000000000004")!
    static let frameAID = UUID(uuidString: "10000000-0000-4000-8000-000000000101")!
    static let frameBID = UUID(uuidString: "10000000-0000-4000-8000-000000000102")!
    static let frameCID = UUID(uuidString: "10000000-0000-4000-8000-000000000103")!
}
