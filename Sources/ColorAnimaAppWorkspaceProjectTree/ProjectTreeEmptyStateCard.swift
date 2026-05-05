import ColorAnimaAppWorkspaceDesignSystem
import SwiftUI

package struct ProjectTreeEmptyStateCard: View {
    package init() {}

    package var body: some View {
        VStack(alignment: .leading, spacing: WorkspaceFoundation.Metrics.compactControlPadding) {
            Text("No sequences yet")
                .font(.headline)
            Text("Create your first sequence to start structuring the project.")
                .font(.callout)
                .foregroundStyle(WorkspaceChromeStyle.Sidebar.secondaryLabel)
        }
        .padding(WorkspaceFoundation.Metrics.space3_5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .chromeCard(
            fill: WorkspaceChromeStyle.Sidebar.panelCardFill,
            stroke: WorkspaceChromeStyle.Sidebar.panelCardStroke,
            cornerRadius: ProjectTreeSidebarMetrics.panelCardCornerRadius
        )
    }
}
