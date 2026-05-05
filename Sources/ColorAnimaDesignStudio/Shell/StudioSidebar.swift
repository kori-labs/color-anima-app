import SwiftUI
import ColorAnimaAppWorkspaceDesignSystem

/// Sidebar listing the four token categories.
struct StudioSidebar: View {
    @Binding var selectedCategory: TokenCategory

    var body: some View {
        List(TokenCategory.allCases, selection: $selectedCategory) { category in
            Text(category.rawValue)
                .font(WorkspaceFoundation.Typography.primaryLabel)
                .tag(category)
        }
        .listStyle(.sidebar)
        .frame(minWidth: 160, idealWidth: 180)
    }
}
