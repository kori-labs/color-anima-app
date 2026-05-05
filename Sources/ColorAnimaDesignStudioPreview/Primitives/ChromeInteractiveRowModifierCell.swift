import SwiftUI
import ColorAnimaAppWorkspaceDesignSystem

/// Preview cell for `View.chromeInteractiveRow(isActive:cornerRadius:)`.
/// Shows idle and active states side by side.
struct ChromeInteractiveRowModifierCell: View {
    var body: some View {
        VStack(spacing: WorkspaceFoundation.Metrics.space2) {
            Text("Idle row")
                .font(WorkspaceFoundation.Typography.secondaryLabel)
                .foregroundStyle(WorkspaceFoundation.Foreground.primaryLabel)
                .padding(.horizontal, WorkspaceFoundation.Metrics.space3)
                .padding(.vertical, WorkspaceFoundation.Metrics.space2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .chromeInteractiveRow(isActive: false, cornerRadius: WorkspaceFoundation.Metrics.rowCornerRadius)

            Text("Active row")
                .font(WorkspaceFoundation.Typography.secondaryLabel)
                .foregroundStyle(WorkspaceFoundation.Foreground.primaryLabel)
                .padding(.horizontal, WorkspaceFoundation.Metrics.space3)
                .padding(.vertical, WorkspaceFoundation.Metrics.space2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .chromeInteractiveRow(isActive: true, cornerRadius: WorkspaceFoundation.Metrics.rowCornerRadius)
        }
    }
}
