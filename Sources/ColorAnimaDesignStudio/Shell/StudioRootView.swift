import SwiftUI
import ColorAnimaAppWorkspaceDesignSystem

/// Three-pane root: sidebar | editor panel | preview placeholder.
struct StudioRootView: View {
    @State private var model = StudioModel()

    var body: some View {
        NavigationSplitView {
            StudioSidebar(selectedSection: $model.selectedSection)
        } content: {
            StudioEditorPanel(model: model)
        } detail: {
            ComponentGalleryView(model: model)
        }
        .background(WorkspaceFoundation.Surface.canvas)
        .overlay(alignment: .top) {
            if let errorMessage = model.loadError {
                Text("Failed to load tokens: \(errorMessage)")
                    .font(WorkspaceFoundation.Typography.caption)
                    .foregroundStyle(WorkspaceFoundation.Foreground.destructiveForeground)
                    .padding(WorkspaceFoundation.Metrics.space2)
                    .background(WorkspaceFoundation.Surface.raised)
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Apply") {}
                    .disabled(true)
                    .help("Wired in Wave 3b (Child 5)")
            }
            if model.isDirty {
                ToolbarItem(placement: .status) {
                    Text("Unsaved changes")
                        .font(WorkspaceFoundation.Typography.caption)
                        .foregroundStyle(WorkspaceFoundation.Foreground.secondaryLabel)
                }
            }
        }
    }
}
