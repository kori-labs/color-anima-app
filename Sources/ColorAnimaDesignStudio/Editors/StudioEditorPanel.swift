import ColorAnimaAppWorkspaceDesignSystem
import ColorAnimaDesignStudioIntegratedPreview
import SwiftUI

/// Switches the editor view based on the selected sidebar section.
struct StudioEditorPanel: View {
    @Bindable var model: StudioModel

    var body: some View {
        Group {
            switch model.selectedSection {
            case .tokenCategory(let category):
                tokenEditor(for: category)
            case .integratedPreviews:
                integratedPreviewPane
            }
        }
        .frame(minWidth: 400)
        .background(WorkspaceFoundation.Surface.canvas)
    }

    // MARK: - Token editors

    @ViewBuilder
    private func tokenEditor(for category: TokenCategory) -> some View {
        switch category {
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

    // MARK: - Integrated preview pane

    private var integratedPreviewPane: some View {
        VStack(spacing: 0) {
            Picker("Screen", selection: $model.selectedIntegratedScreen) {
                ForEach(IntegratedPreviewScreen.allCases) { screen in
                    Text(screen.title).tag(screen)
                }
            }
            .pickerStyle(.segmented)
            .padding(WorkspaceFoundation.Metrics.space3)
            .background(WorkspaceFoundation.Surface.raised)

            Divider()

            IntegratedPreviewView(screen: model.selectedIntegratedScreen)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
