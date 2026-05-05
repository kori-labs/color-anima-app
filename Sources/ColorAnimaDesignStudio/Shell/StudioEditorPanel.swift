import SwiftUI
import ColorAnimaAppWorkspaceDesignSystem

/// Switches the editor view based on the selected token category.
struct StudioEditorPanel: View {
    @Bindable var model: StudioModel

    var body: some View {
        Group {
            switch model.selectedCategory {
            case .colors:
                ColorTokenEditor(tokens: $model.colors) { index, token in
                    model.updateColor(token, at: index)
                }
            case .spacing:
                SpacingTokenEditor(tokens: $model.spacing) { index, token in
                    model.updateSpacing(token, at: index)
                }
            case .typography:
                TypographyTokenEditor(tokens: $model.typography) { index, token in
                    model.updateTypography(token, at: index)
                }
            case .cornerRadii:
                CornerRadiusTokenEditor(tokens: $model.cornerRadii) { index, token in
                    model.updateCornerRadius(token, at: index)
                }
            }
        }
        .frame(minWidth: 400)
        .background(WorkspaceFoundation.Surface.canvas)
    }
}
