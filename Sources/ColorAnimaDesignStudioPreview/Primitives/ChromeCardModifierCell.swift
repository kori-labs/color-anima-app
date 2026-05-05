import SwiftUI
import ColorAnimaAppWorkspaceDesignSystem

/// Preview cell for `View.chromeCard(fill:stroke:cornerRadius:)`.
/// Renders a sample content block with the chromeCard modifier applied.
struct ChromeCardModifierCell: View {
    var body: some View {
        Text("chromeCard content")
            .font(WorkspaceFoundation.Typography.secondaryLabel)
            .foregroundStyle(WorkspaceFoundation.Foreground.primaryLabel)
            .padding(.horizontal, WorkspaceFoundation.Metrics.space3)
            .padding(.vertical, WorkspaceFoundation.Metrics.space2)
            .chromeCard(
                fill: WorkspaceFoundation.Surface.cardFill,
                stroke: WorkspaceFoundation.Stroke.divider,
                cornerRadius: WorkspaceFoundation.Metrics.rowCornerRadius
            )
    }
}
