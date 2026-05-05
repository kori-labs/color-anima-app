import SwiftUI
import ColorAnimaAppWorkspaceDesignSystem

/// Preview cell for `View.chromeSelectablePanelCard(isActive:cornerRadius:)`.
/// Shows idle and active selection states side by side.
struct ChromeSelectablePanelCardCell: View {
    var body: some View {
        VStack(spacing: WorkspaceFoundation.Metrics.space2) {
            Text("Idle panel card")
                .font(WorkspaceFoundation.Typography.secondaryLabel)
                .foregroundStyle(WorkspaceFoundation.Foreground.primaryLabel)
                .padding(.horizontal, WorkspaceFoundation.Metrics.space3)
                .padding(.vertical, WorkspaceFoundation.Metrics.space2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .chromeSelectablePanelCard(isActive: false, cornerRadius: WorkspaceFoundation.Metrics.cardCornerRadius)

            Text("Active panel card")
                .font(WorkspaceFoundation.Typography.secondaryLabel)
                .foregroundStyle(WorkspaceFoundation.Foreground.primaryLabel)
                .padding(.horizontal, WorkspaceFoundation.Metrics.space3)
                .padding(.vertical, WorkspaceFoundation.Metrics.space2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .chromeSelectablePanelCard(isActive: true, cornerRadius: WorkspaceFoundation.Metrics.cardCornerRadius)
        }
    }
}
