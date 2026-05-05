import SwiftUI

/// Top-level switcher: renders the composite for the selected screen.
public struct IntegratedPreviewView: View {
    public let screen: IntegratedPreviewScreen

    public init(screen: IntegratedPreviewScreen) {
        self.screen = screen
    }

    public var body: some View {
        switch screen {
        case .intake:
            IntakeCompositeView()
        case .workspaceShell:
            WorkspaceShellCompositeView()
        case .cutEditor:
            CutEditorCompositeView()
        case .inspector:
            InspectorCompositeView()
        }
    }
}
