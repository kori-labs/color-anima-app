import ColorAnimaAppWorkspaceApplication
import ColorAnimaAppWorkspaceDesignSystem
import SwiftUI

struct ProjectTreeRow: View {
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

    @State private var isHovered = false

    private var isSelected: Bool {
        selection.selectedNodeIDs.contains(node.id)
    }

    private var isEditing: Bool {
        editingNodeID == node.id
    }

    private var hasChildren: Bool {
        node.children.isEmpty == false
    }

    private var isCollapsed: Bool {
        collapsedNodeIDs.contains(node.id)
    }

    private var isDropTarget: Bool {
        dropTargetNodeID == node.id && dropTargetPosition != nil
    }

    private var activeDropPosition: ProjectTreeDropPosition? {
        guard dropTargetNodeID == node.id else { return nil }
        return dropTargetPosition
    }

    private var isDeletable: Bool {
        node.kind != .project
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 0) {
                TreeConnectorGutter(
                    depth: depth,
                    isLastSibling: isLastSibling,
                    ancestorContinuationColumns: ancestorContinuationColumns
                )

                nodeCard
            }

            if hasChildren && !isCollapsed {
                ProjectTreeChildrenView(
                    node: node,
                    rootNode: rootNode,
                    depth: depth,
                    isLastSibling: isLastSibling,
                    ancestorContinuationColumns: ancestorContinuationColumns,
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

            if activeDropPosition == .append {
                appendInsertionRow
            }
        }
    }

    @ViewBuilder
    private var nodeCard: some View {
        if isEditing {
            nodeCardContent
        } else {
            nodeCardContent
                .simultaneousGesture(
                    TapGesture(count: 2).onEnded {
                        callbacks.onStartRename(node)
                    }
                )
                .simultaneousGesture(
                    TapGesture(count: 1).onEnded {
                        callbacks.onSelectNode(node.id, ProjectTreeRowState.currentSelectionModifiers())
                    }
                )
                .onDrag {
                    ProjectTreeRowState.makeDragItemProvider(
                        node: node,
                        selectedNodeIDs: selection.selectedNodeIDs,
                        rootNode: rootNode,
                        setDraggedNodeIDs: { draggedNodeIDs = $0 }
                    )
                }
                .background {
                    GeometryReader { proxy in
                        projectTreeRowDropTarget(
                            delegate: dropDelegate(rowHeight: proxy.size.height)
                        )
                    }
                }
        }
    }

    private var nodeCardContent: some View {
        HStack(spacing: 10) {
            leadingControl

            VStack(alignment: .leading, spacing: 1) {
                if isEditing {
                    InlineRenameField(
                        text: $editingNodeName,
                        placeholder: "\(ProjectTreeRowState.title(for: node.kind)) name",
                        onCommit: { callbacks.onCommitRename(node.id) },
                        onCancel: callbacks.onCancelRename
                    )
                } else {
                    Text(node.name)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(ProjectTreeRowState.labelForegroundStyle(
                            isSelected: isSelected,
                            isHovered: isHovered
                        ))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .layoutPriority(1)
                }

                Text(ProjectTreeRowState.title(for: node.kind))
                    .font(.caption2)
                    .foregroundStyle(WorkspaceChromeStyle.Sidebar.secondaryLabel)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            if isDeletable {
                HoverDeleteConfirmButton(
                    isVisible: isHovered && !isEditing,
                    resetToken: selection.selectedNodeID.map(AnyHashable.init),
                    onConfirm: { callbacks.onDeleteNode(node.id) }
                )
            }
        }
        .padding(.vertical, ProjectTreeSidebarMetrics.rowVerticalPadding)
        .padding(.horizontal, ProjectTreeSidebarMetrics.rowHorizontalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ProjectTreeRowState.rowFill(
            node: node,
            isHovered: isHovered,
            isSelected: isSelected,
            isDropTarget: isDropTarget
        ))
        .overlay {
            RoundedRectangle(cornerRadius: ProjectTreeSidebarMetrics.rowCornerRadius, style: .continuous)
                .strokeBorder(ProjectTreeRowState.rowStroke(
                    node: node,
                    isHovered: isHovered,
                    isSelected: isSelected,
                    isDropTarget: isDropTarget
                ), lineWidth: 1)
        }
        .clipShape(.rect(cornerRadius: ProjectTreeSidebarMetrics.rowCornerRadius))
        .overlay(alignment: .top) {
            if activeDropPosition == .before {
                edgeInsertionIndicator
                    .offset(y: -Self.edgeIndicatorOffset)
            }
        }
        .overlay(alignment: .bottom) {
            if activeDropPosition == .after {
                edgeInsertionIndicator
                    .offset(y: Self.edgeIndicatorOffset)
            }
        }
        .contentShape(.rect)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private var leadingControl: some View {
        ZStack {
            if hasChildren && ProjectTreeRowState.showsActiveRowState(
                isHovered: isHovered,
                isSelected: isSelected,
                isDropTarget: isDropTarget
            ) {
                Button {
                    toggleCollapsed()
                } label: {
                    Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(ProjectTreeRowState.iconForegroundStyle(
                            isSelected: isSelected,
                            isHovered: isHovered
                        ))
                        .frame(width: 16, height: 16)
                }
                .accessibilityLabel(isCollapsed ? "Expand" : "Collapse")
                .buttonStyle(
                    ChromeButtonStyle(
                        horizontalPadding: 0,
                        verticalPadding: 0,
                        cornerRadius: 7
                    )
                )
            } else {
                Image(systemName: ProjectTreeRowState.systemImage(for: node.kind))
                    .frame(width: 16, height: 16)
                    .foregroundStyle(ProjectTreeRowState.iconForegroundStyle(
                        isSelected: isSelected,
                        isHovered: isHovered
                    ))
            }
        }
        .frame(
            width: ProjectTreeSidebarMetrics.leadingControlSlotWidth,
            height: ProjectTreeSidebarMetrics.leadingControlSlotWidth
        )
    }

    private func dropDelegate(rowHeight: CGFloat) -> some DropDelegate {
        ProjectTreeRowDropDelegate(
            node: node,
            rootNode: rootNode,
            rowHeight: rowHeight,
            draggedNodeIDs: { Array(draggedNodeIDs) },
            currentDropPosition: {
                dropTargetNodeID == node.id ? dropTargetPosition : nil
            },
            setDropPosition: { position in
                if let position {
                    dropTargetNodeID = node.id
                    dropTargetPosition = position
                } else if dropTargetNodeID == node.id {
                    dropTargetNodeID = nil
                    dropTargetPosition = nil
                }
            },
            performMove: { nodeIDs, position in
                callbacks.onMoveTreeNodes(nodeIDs, node.id, position)
            },
            clearDragState: {
                draggedNodeIDs.removeAll()
                dropTargetNodeID = nil
                dropTargetPosition = nil
            }
        )
    }

    private var edgeInsertionIndicator: some View {
        RoundedRectangle(cornerRadius: Self.insertionIndicatorThickness / 2, style: .continuous)
            .fill(WorkspaceChromeStyle.treeConnectorStroke)
            .frame(height: Self.insertionIndicatorThickness)
            .shadow(color: WorkspaceChromeStyle.treeConnectorStroke.opacity(0.12), radius: 2, y: 0)
            .allowsHitTesting(false)
    }

    private var appendInsertionRow: some View {
        HStack(spacing: 0) {
            Color.clear
                .frame(width: childInsertionIndent)

            edgeInsertionIndicator
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, hasChildren && !isCollapsed ? 2 : 0)
    }

    private var childInsertionIndent: CGFloat {
        ProjectTreeHierarchyMetrics.gutterWidth(for: depth + 1)
            + ProjectTreeSidebarMetrics.leadingControlSlotWidth
            + ProjectTreeSidebarMetrics.rowHorizontalPadding
    }

    private func toggleCollapsed() {
        ProjectTreeCollapsePolicy.toggle(
            node: node,
            selectedNodeIDs: selection.selectedNodeIDs,
            collapsedNodeIDs: &collapsedNodeIDs,
            onSelectNode: { nodeID, modifiers in
                callbacks.onSelectNode(nodeID, modifiers)
            }
        )
    }

    // MARK: - Layout constants

    private static let insertionIndicatorThickness: CGFloat = 3
    private static let edgeIndicatorOffset: CGFloat = 5
}
