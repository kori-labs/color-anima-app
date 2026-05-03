import AppKit
import ColorAnimaAppWorkspaceApplication
import ColorAnimaAppWorkspaceDesignSystem
import Foundation
import SwiftUI

package enum ProjectTreeRowState {
    package static func dragSelectionIDs(
        for node: WorkspaceProjectTreeNode,
        selectedNodeIDs: Set<UUID>,
        rootNode: WorkspaceProjectTreeNode
    ) -> [UUID] {
        guard selectedNodeIDs.contains(node.id) else {
            return [node.id]
        }

        if ProjectTreeActionRules.canMoveSelection(
            selectedNodeIDs,
            to: node.id,
            position: .append,
            in: rootNode
        ) {
            return ProjectTreeActionRules.orderedSelectionIDs(selectedNodeIDs, in: rootNode)
        }

        return [node.id]
    }

    @MainActor
    package static func currentSelectionModifiers() -> WorkspaceSelectionModifiers {
        let modifierFlags = NSApp.currentEvent?.modifierFlags ?? []
        var modifiers = WorkspaceSelectionModifiers()
        if modifierFlags.contains(.command) {
            modifiers.insert(.additive)
        }
        if modifierFlags.contains(.shift) {
            modifiers.insert(.range)
        }
        return modifiers
    }

    @MainActor
    package static func makeDragItemProvider(
        node: WorkspaceProjectTreeNode,
        selectedNodeIDs: Set<UUID>,
        rootNode: WorkspaceProjectTreeNode,
        setDraggedNodeIDs: (Set<UUID>) -> Void
    ) -> NSItemProvider {
        let draggedIDs = dragSelectionIDs(
            for: node,
            selectedNodeIDs: selectedNodeIDs,
            rootNode: rootNode
        )
        setDraggedNodeIDs(Set(draggedIDs))
        return NSItemProvider(object: NSString(string: draggedIDs.map(\.uuidString).joined(separator: ",")))
    }

    package static func rowFill(
        node: WorkspaceProjectTreeNode,
        isHovered: Bool,
        isSelected: Bool,
        isDropTarget: Bool
    ) -> Color {
        if node.kind != .project, showsActiveRowState(isHovered: isHovered, isSelected: isSelected, isDropTarget: isDropTarget) {
            return WorkspaceChromeStyle.SelectablePanelCard.activeFill
        }

        if node.kind == .project {
            if isDropTarget {
                return WorkspaceChromeStyle.treeRowSelectedFill.opacity(0.9)
            }
            if isSelected {
                return WorkspaceChromeStyle.treeRowSelectedFill
            }
            if isHovered {
                return WorkspaceChromeStyle.treeRowHoverFill
            }
            return WorkspaceChromeStyle.treeRowFill
        }
        return .clear
    }

    package static func rowStroke(
        node: WorkspaceProjectTreeNode,
        isHovered: Bool,
        isSelected: Bool,
        isDropTarget: Bool
    ) -> Color {
        if node.kind != .project {
            return showsActiveRowState(isHovered: isHovered, isSelected: isSelected, isDropTarget: isDropTarget)
                ? WorkspaceChromeStyle.SelectablePanelCard.activeStroke
                : WorkspaceChromeStyle.SelectablePanelCard.idleStroke
        }

        if isSelected {
            return WorkspaceChromeStyle.treeRowSelectedBorder
        }
        if isDropTarget || isHovered {
            return WorkspaceChromeStyle.Sidebar.interactiveHoverStroke
        }
        return WorkspaceChromeStyle.treeRowBorder
    }

    package static func iconForegroundStyle(
        isSelected: Bool,
        isHovered: Bool
    ) -> Color {
        if isSelected {
            return WorkspaceChromeStyle.Sidebar.selectionAccent
        }
        if isHovered {
            return WorkspaceChromeStyle.Sidebar.primaryLabel
        }
        return WorkspaceChromeStyle.Sidebar.secondaryLabel
    }

    package static func labelForegroundStyle(
        isSelected: Bool,
        isHovered: Bool
    ) -> Color {
        iconForegroundStyle(isSelected: isSelected, isHovered: isHovered)
    }

    package static func title(for kind: WorkspaceProjectTreeNodeKind) -> String {
        switch kind {
        case .project:
            return "Project"
        case .sequence:
            return "Sequence"
        case .scene:
            return "Scene"
        case .cut:
            return "Cut"
        }
    }

    package static func systemImage(for kind: WorkspaceProjectTreeNodeKind) -> String {
        switch kind {
        case .project, .sequence:
            return "folder"
        case .scene:
            return "rectangle.on.rectangle"
        case .cut:
            return "film"
        }
    }

    package static func showsActiveRowState(
        isHovered: Bool,
        isSelected: Bool,
        isDropTarget: Bool
    ) -> Bool {
        isHovered || isSelected || isDropTarget
    }
}
