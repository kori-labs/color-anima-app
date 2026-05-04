import ColorAnimaAppWorkspaceApplication
import SwiftUI

struct ProjectTreeChildrenView: View {
    let node: WorkspaceProjectTreeNode
    let rootNode: WorkspaceProjectTreeNode
    let depth: Int
    let isLastSibling: Bool
    let ancestorContinuationColumns: [Bool]
    let selection: ProjectTreeRowSelectionContext
    let callbacks: ProjectTreeRowCallbacks
    let editingNodeID: UUID?
    @Binding var editingNodeName: String
    @Binding var collapsedNodeIDs: Set<UUID>
    @Binding var draggedNodeIDs: Set<UUID>
    @Binding var dropTargetNodeID: UUID?
    @Binding var dropTargetPosition: ProjectTreeDropPosition?

    var body: some View {
        VStack(alignment: .leading, spacing: ProjectTreeSidebarMetrics.childSpacing) {
            ForEach(Array(node.children.enumerated()), id: \.element.id) { index, child in
                ProjectTreeRow(
                    node: child,
                    rootNode: rootNode,
                    depth: depth + 1,
                    isLastSibling: index == node.children.count - 1,
                    ancestorContinuationColumns: ProjectTreeHierarchyMetrics.childContinuationColumns(
                        ancestorContinuationColumns: ancestorContinuationColumns,
                        isCurrentNodeLastSibling: isLastSibling
                    ),
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
        .padding(.top, 2)
    }
}
