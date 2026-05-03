import SwiftUI

// swiftformat:disable extensionAccessControl
extension WorkspaceChromeStyle {
    package static var treeRowFill: Color {
        Sidebar.panelCardFill
    }

    package static var treeRowBorder: Color {
        Sidebar.panelCardStroke
    }

    package static var treeRowHoverFill: Color {
        Sidebar.interactiveHoverFill
    }

    package static var treeRowSelectedFill: Color {
        Color.accentColor.opacity(0.12)
    }

    package static var treeRowSelectedBorder: Color {
        Color.accentColor.opacity(0.34)
    }

    package static var treeRowSelectedAccent: Color {
        WorkspaceFoundation.Selection.selectionAccent
    }

    package static var treeMetaLabel: Color {
        WorkspaceFoundation.Foreground.secondaryLabel
    }

    package static var treeConnectorStroke: Color {
        Sidebar.connectorStroke
    }
}

// swiftformat:enable extensionAccessControl
