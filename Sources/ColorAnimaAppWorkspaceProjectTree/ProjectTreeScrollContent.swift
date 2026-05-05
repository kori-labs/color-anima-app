import ColorAnimaAppWorkspaceApplication
import ColorAnimaAppWorkspaceDesignSystem
import SwiftUI

package struct ProjectTreeScrollContentState {
    let isEmpty: Bool
    let rootRowCount: Int

    package init(rootNode: WorkspaceProjectTreeNode) {
        isEmpty = rootNode.children.isEmpty
        rootRowCount = rootNode.children.count
    }
}

package struct ProjectTreeScrollContent: View {
    let rootNode: WorkspaceProjectTreeNode
    let selectedNodeID: UUID?
    let selectedNodeIDs: Set<UUID>
    let selectionAnchorNodeID: UUID?
    let onSelectNode: (UUID, WorkspaceSelectionModifiers) -> Void
    let onMoveTreeNodes: ([UUID], UUID, ProjectTreeDropPosition) -> Void
    let onDeleteNode: (UUID) -> Void
    let onStartRename: (WorkspaceProjectTreeNode) -> Void
    let onCommitRename: (UUID) -> Void
    let onCancelRename: () -> Void
    @Binding var editingNodeID: UUID?
    @Binding var editingNodeName: String
    @Binding var collapsedNodeIDs: Set<UUID>
    @Binding var draggedNodeIDs: Set<UUID>
    @Binding var dropTargetNodeID: UUID?
    @Binding var dropTargetPosition: ProjectTreeDropPosition?

    package init(
        rootNode: WorkspaceProjectTreeNode,
        selectedNodeID: UUID?,
        selectedNodeIDs: Set<UUID>,
        selectionAnchorNodeID: UUID?,
        onSelectNode: @escaping (UUID, WorkspaceSelectionModifiers) -> Void,
        onMoveTreeNodes: @escaping ([UUID], UUID, ProjectTreeDropPosition) -> Void,
        onDeleteNode: @escaping (UUID) -> Void,
        onStartRename: @escaping (WorkspaceProjectTreeNode) -> Void,
        onCommitRename: @escaping (UUID) -> Void,
        onCancelRename: @escaping () -> Void,
        editingNodeID: Binding<UUID?>,
        editingNodeName: Binding<String>,
        collapsedNodeIDs: Binding<Set<UUID>>,
        draggedNodeIDs: Binding<Set<UUID>>,
        dropTargetNodeID: Binding<UUID?>,
        dropTargetPosition: Binding<ProjectTreeDropPosition?>
    ) {
        self.rootNode = rootNode
        self.selectedNodeID = selectedNodeID
        self.selectedNodeIDs = selectedNodeIDs
        self.selectionAnchorNodeID = selectionAnchorNodeID
        self.onSelectNode = onSelectNode
        self.onMoveTreeNodes = onMoveTreeNodes
        self.onDeleteNode = onDeleteNode
        self.onStartRename = onStartRename
        self.onCommitRename = onCommitRename
        self.onCancelRename = onCancelRename
        _editingNodeID = editingNodeID
        _editingNodeName = editingNodeName
        _collapsedNodeIDs = collapsedNodeIDs
        _draggedNodeIDs = draggedNodeIDs
        _dropTargetNodeID = dropTargetNodeID
        _dropTargetPosition = dropTargetPosition
    }

    package var body: some View {
        let state = ProjectTreeScrollContentState(rootNode: rootNode)

        ScrollView {
            VStack(alignment: .leading, spacing: ProjectTreeSidebarMetrics.treeSpacing) {
                if state.isEmpty {
                    ProjectTreeEmptyStateCard()
                        .padding(.top, WorkspaceFoundation.Metrics.microSpace0_5)
                } else {
                    rootRows
                }
            }
            .padding(.horizontal, ProjectTreeSidebarMetrics.edgePadding)
            .padding(.top, WorkspaceFoundation.Metrics.space1)
            .padding(.bottom, ProjectTreeSidebarMetrics.edgePadding)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private var rootRows: some View {
        let selection = ProjectTreeRowSelectionContext(
            selectedNodeID: selectedNodeID,
            selectedNodeIDs: selectedNodeIDs,
            selectionAnchorNodeID: selectionAnchorNodeID
        )
        let callbacks = ProjectTreeRowCallbacks(
            onSelectNode: onSelectNode,
            onMoveTreeNodes: onMoveTreeNodes,
            onStartRename: onStartRename,
            onCommitRename: onCommitRename,
            onCancelRename: onCancelRename,
            onDeleteNode: onDeleteNode
        )
        ForEach(Array(rootNode.children.enumerated()), id: \.element.id) { index, child in
            ProjectTreeRow(
                node: child,
                rootNode: rootNode,
                depth: 0,
                isLastSibling: index == rootNode.children.count - 1,
                ancestorContinuationColumns: [],
                selection: selection,
                callbacks: callbacks,
                editingNodeID: editingNodeID,
                editingNodeName: $editingNodeName,
                collapsedNodeIDs: $collapsedNodeIDs,
                draggedNodeIDs: $draggedNodeIDs,
                dropTargetNodeID: $dropTargetNodeID,
                dropTargetPosition: $dropTargetPosition
            )
        }
    }
}
