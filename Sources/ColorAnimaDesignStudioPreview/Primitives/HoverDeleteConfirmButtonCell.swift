import SwiftUI
import ColorAnimaAppWorkspaceDesignSystem

/// Preview cell for `HoverDeleteConfirmButton`.
/// Renders the button in its idle visible state with a stub confirm closure.
struct HoverDeleteConfirmButtonCell: View {
    var body: some View {
        HStack(spacing: WorkspaceFoundation.Metrics.space3) {
            Text("Sample row item")
                .font(WorkspaceFoundation.Typography.secondaryLabel)
                .foregroundStyle(WorkspaceFoundation.Foreground.primaryLabel)

            Spacer()

            HoverDeleteConfirmButton(isVisible: true, onConfirm: {})
        }
        .padding(.horizontal, WorkspaceFoundation.Metrics.space3)
        .padding(.vertical, WorkspaceFoundation.Metrics.space2)
        .background(WorkspaceFoundation.Surface.raised)
        .clipShape(RoundedRectangle(cornerRadius: WorkspaceFoundation.Metrics.rowCornerRadius))
    }
}
