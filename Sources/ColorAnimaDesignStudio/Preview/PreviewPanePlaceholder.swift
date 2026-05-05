import SwiftUI
import ColorAnimaAppWorkspaceDesignSystem

/// Placeholder for the live preview pane. Populated in Wave 4 (Child 4).
struct PreviewPanePlaceholder: View {
    var body: some View {
        VStack(spacing: WorkspaceFoundation.Metrics.space4) {
            Text("Preview pane — Wave 4 (Child 4) will populate this.")
                .font(WorkspaceFoundation.Typography.secondaryLabel)
                .foregroundStyle(WorkspaceFoundation.Foreground.secondaryLabel)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WorkspaceFoundation.Surface.canvas)
    }
}
