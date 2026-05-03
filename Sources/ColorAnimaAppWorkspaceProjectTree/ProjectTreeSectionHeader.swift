import ColorAnimaAppWorkspaceDesignSystem
import SwiftUI

package struct ProjectTreeSectionHeader: View {
    let onCreateSequence: () -> Void

    package var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Text("Sequences")
                .font(.caption.weight(.semibold))
                .foregroundStyle(WorkspaceChromeStyle.Sidebar.secondaryLabel)

            Spacer(minLength: 0)

            Button(action: onCreateSequence) {
                Image(systemName: "folder.badge.plus")
                    .font(.caption.weight(.semibold))
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(
                ChromeButtonStyle(
                    horizontalPadding: ProjectTreeSidebarMetrics.compactControlPadding,
                    verticalPadding: ProjectTreeSidebarMetrics.compactControlPadding,
                    cornerRadius: ProjectTreeSidebarMetrics.compactControlCornerRadius,
                    idleForegroundStyle: WorkspaceChromeStyle.Sidebar.secondaryLabel,
                    hoverForegroundStyle: WorkspaceChromeStyle.Sidebar.primaryLabel
                )
            )
            .accessibilityLabel("Add Sequence")
        }
    }
}
