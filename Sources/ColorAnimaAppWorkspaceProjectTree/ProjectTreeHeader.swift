import ColorAnimaAppWorkspaceDesignSystem
import SwiftUI

package struct ProjectTreeHeader: View {
    let projectName: String
    let onOpenProjectSettings: () -> Void

    package var body: some View {
        VStack(alignment: .leading, spacing: ProjectTreeSidebarMetrics.headerStackSpacing) {
            HStack(alignment: .center, spacing: ProjectTreeSidebarMetrics.titleRowSpacing) {
                Text(projectName)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(WorkspaceChromeStyle.Sidebar.primaryLabel)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .layoutPriority(1)

                Button(action: onOpenProjectSettings) {
                    Image(systemName: "gearshape")
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
                .accessibilityLabel("Project Settings")

                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
