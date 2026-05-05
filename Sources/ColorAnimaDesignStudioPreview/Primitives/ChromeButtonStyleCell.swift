import SwiftUI
import ColorAnimaAppWorkspaceDesignSystem

/// Preview cell for `ChromeButtonStyle`.
/// Renders idle, hover-styled, and destructive variants side by side.
struct ChromeButtonStyleCell: View {
    var body: some View {
        HStack(spacing: WorkspaceFoundation.Metrics.space3) {
            Button("Default") {}
                .buttonStyle(ChromeButtonStyle())

            Button("Destructive") {}
                .buttonStyle(ChromeButtonStyle(isDestructive: true))

            Button("Wide") {}
                .buttonStyle(ChromeButtonStyle(expandToMaxWidth: true))
        }
    }
}
