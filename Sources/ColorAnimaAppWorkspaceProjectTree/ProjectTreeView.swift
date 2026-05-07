import ColorAnimaAppWorkspaceApplication
import ColorAnimaAppWorkspaceDesignSystem
import SwiftUI

package struct ProjectTreeView: View {
    private struct SelectionSyncSnapshot: Equatable {
        let selectedNodeID: UUID?
        let selectedNodeIDs: Set<UUID>
        let selectionAnchorNodeID: UUID?
    }

    let rootNode: WorkspaceProjectTreeNode
    let selectedNodeID: UUID?
    let selectedNodeIDs: Set<UUID>
    let selectionAnchorNodeID: UUID?
    let selectedNode: WorkspaceProjectTreeNode?
    let onSelectNode: (UUID, WorkspaceSelectionModifiers) -> Void
    let onMoveTreeNodes: ([UUID], UUID, ProjectTreeDropPosition) -> Void
    let onRenameNode: (UUID, String) -> Void
    let onCreateSequence: () -> Void
    let onCreateScene: (UUID) -> Void
    let onCreateCut: (UUID) -> Void
    let onOpenProjectSettings: () -> Void
    let onDeleteNode: (UUID) -> Void

    @State private var viewState = ProjectTreeViewState()
    private let lifecycle: any ProjectTreeViewLifecycleManaging

    package init(
        rootNode: WorkspaceProjectTreeNode,
        selectedNodeID: UUID?,
        selectedNodeIDs: Set<UUID>,
        selectionAnchorNodeID: UUID?,
        selectedNode: WorkspaceProjectTreeNode?,
        onSelectNode: @escaping (UUID, WorkspaceSelectionModifiers) -> Void,
        onMoveTreeNodes: @escaping ([UUID], UUID, ProjectTreeDropPosition) -> Void,
        onRenameNode: @escaping (UUID, String) -> Void,
        onCreateSequence: @escaping () -> Void,
        onCreateScene: @escaping (UUID) -> Void,
        onCreateCut: @escaping (UUID) -> Void,
        onOpenProjectSettings: @escaping () -> Void,
        onDeleteNode: @escaping (UUID) -> Void,
        lifecycle: any ProjectTreeViewLifecycleManaging = ProjectTreeViewLifecycle()
    ) {
        self.rootNode = rootNode
        self.selectedNodeID = selectedNodeID
        self.selectedNodeIDs = selectedNodeIDs
        self.selectionAnchorNodeID = selectionAnchorNodeID
        self.selectedNode = selectedNode
        self.onSelectNode = onSelectNode
        self.onMoveTreeNodes = onMoveTreeNodes
        self.onRenameNode = onRenameNode
        self.onCreateSequence = onCreateSequence
        self.onCreateScene = onCreateScene
        self.onCreateCut = onCreateCut
        self.onOpenProjectSettings = onOpenProjectSettings
        self.onDeleteNode = onDeleteNode
        self.lifecycle = lifecycle
    }

    package var body: some View {
        VStack(spacing: 0) {
            ProjectTreeHeader(
                projectName: displayProjectName,
                onOpenProjectSettings: onOpenProjectSettings
            )
            .padding(.horizontal, ProjectTreeSidebarMetrics.edgePadding)
            .padding(.top, ProjectTreeSidebarMetrics.headerTopPadding)

            ProjectTreeSectionHeader(onCreateSequence: onCreateSequence)
                .padding(.horizontal, ProjectTreeSidebarMetrics.edgePadding)
                .padding(.top, ProjectTreeSidebarMetrics.sectionTopPadding)
                .padding(.bottom, ProjectTreeSidebarMetrics.sectionBottomPadding)

            ProjectTreeScrollContent(
                rootNode: rootNode,
                selectedNodeID: selectedNodeID,
                selectedNodeIDs: selectedNodeIDs,
                selectionAnchorNodeID: selectionAnchorNodeID,
                onSelectNode: onSelectNode,
                onMoveTreeNodes: onMoveTreeNodes,
                onDeleteNode: onDeleteNode,
                onStartRename: startNodeRename,
                onCommitRename: commitNodeRename,
                onCancelRename: cancelNodeRename,
                editingNodeID: $viewState.editingNodeID,
                editingNodeName: $viewState.editingNodeName,
                collapsedNodeIDs: $viewState.collapsedNodeIDs,
                draggedNodeIDs: $viewState.draggedNodeIDs,
                dropTargetNodeID: $viewState.dropTargetNodeID,
                dropTargetPosition: $viewState.dropTargetPosition
            )

            ProjectTreeFooter(
                selectedNodeID: selectedNodeID,
                selectedNode: selectedNode,
                rootNode: rootNode,
                onCreateSequence: onCreateSequence,
                onCreateScene: onCreateScene,
                onCreateCut: onCreateCut
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            Rectangle()
                .fill(WorkspaceFoundation.Surface.surfaceFill)
                .ignoresSafeArea()
        }
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(WorkspaceFoundation.Stroke.divider)
                .frame(width: 1)
        }
        .onAppear {
            lifecycle.synchronizeTreeState(
                &viewState,
                rootNode: rootNode,
                selectedNodeID: selectedNodeID,
                selectedNodeIDs: selectedNodeIDs,
                selectionAnchorNodeID: selectionAnchorNodeID
            )
        }
        .onChange(of: rootNode) {
            lifecycle.synchronizeTreeState(
                &viewState,
                rootNode: rootNode,
                selectedNodeID: selectedNodeID,
                selectedNodeIDs: selectedNodeIDs,
                selectionAnchorNodeID: selectionAnchorNodeID
            )
        }
        .onChange(of: selectionSyncSnapshot) {
            lifecycle.synchronizeSelectionState(
                &viewState,
                rootNode: rootNode,
                selectedNodeID: selectedNodeID,
                selectedNodeIDs: selectedNodeIDs,
                selectionAnchorNodeID: selectionAnchorNodeID
            )
        }
    }

    private var displayProjectName: String {
        rootNode.name.isEmpty ? "Untitled Project" : rootNode.name
    }

    private var selectionSyncSnapshot: SelectionSyncSnapshot {
        SelectionSyncSnapshot(
            selectedNodeID: selectedNodeID,
            selectedNodeIDs: selectedNodeIDs,
            selectionAnchorNodeID: selectionAnchorNodeID
        )
    }

    private func startNodeRename(_ node: WorkspaceProjectTreeNode) {
        viewState.startNodeRename(node, onSelectNode: { nodeID in
            onSelectNode(nodeID, [])
        })
    }

    private func commitNodeRename(_ nodeID: UUID) {
        viewState.commitNodeRename(nodeID, onRenameNode: onRenameNode)
    }

    private func cancelNodeRename() {
        viewState.cancelNodeRename()
    }
}
