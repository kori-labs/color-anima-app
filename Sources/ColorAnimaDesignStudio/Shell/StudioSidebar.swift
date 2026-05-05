import ColorAnimaAppWorkspaceDesignSystem
import SwiftUI

/// Sidebar listing token categories and the integrated preview entry.
struct StudioSidebar: View {
    @Binding var selectedSection: StudioSidebarSection

    var body: some View {
        List(selection: $selectedSection) {
            Section("Design Tokens") {
                ForEach(TokenCategory.allCases) { category in
                    Text(category.rawValue)
                        .font(WorkspaceFoundation.Typography.primaryLabel)
                        .tag(StudioSidebarSection.tokenCategory(category))
                }
            }

            Section("Screens") {
                Text("Integrated Previews")
                    .font(WorkspaceFoundation.Typography.primaryLabel)
                    .tag(StudioSidebarSection.integratedPreviews)
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 160, idealWidth: 180)
    }
}
