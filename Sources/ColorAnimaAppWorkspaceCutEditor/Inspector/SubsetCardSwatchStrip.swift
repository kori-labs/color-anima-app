import ColorAnimaAppWorkspaceApplication
import SwiftUI

package struct SubsetCardSwatchStrip: View {
    let subsetID: UUID
    let palette: StatusPalette
    let isSelected: Bool
    let selectedSwatchKind: RoleSwatchKind
    let baseColorSelection: Binding<Color>?
    let highlightColorSelection: Binding<Color>?
    let shadowColorSelection: Binding<Color>?
    let colorPanelPresenter: any RoleSwatchColorPanelPresenting
    let onSelectSubset: (UUID) -> Void
    let onSelectSwatch: (RoleSwatchKind) -> Void

    package var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 12) {
                swatchView(
                    kind: .base,
                    title: "Base",
                    color: palette.roles.base.swiftUIColor,
                    selection: baseColorSelection
                )
                swatchView(
                    kind: .highlight,
                    title: "Highlight",
                    color: palette.roles.highlight.swiftUIColor,
                    selection: highlightColorSelection
                )
                swatchView(
                    kind: .shadow,
                    title: "Shadow",
                    color: palette.roles.shadow.swiftUIColor,
                    selection: shadowColorSelection
                )
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 54)
        .contentMargins(.trailing, 1, for: .scrollContent)
        .defaultScrollAnchor(.leading)
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        .clipped()
        .accessibilityLabel("Subset swatches")
        .accessibilityHint("Scroll horizontally to view all color roles when the inspector is narrow")
    }

    private func swatchView(
        kind: RoleSwatchKind,
        title: String,
        color: Color,
        selection: Binding<Color>?
    ) -> some View {
        RoleSwatchView(
            kind: kind,
            title: title,
            color: color,
            isSelected: isSelected && selectedSwatchKind == kind,
            selection: isSelected ? selection : nil,
            onSelect: {
                onSelectSwatch(kind)
                onSelectSubset(subsetID)
            },
            colorPanelPresenter: colorPanelPresenter
        )
    }
}
