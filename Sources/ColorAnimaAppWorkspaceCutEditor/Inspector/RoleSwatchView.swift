import ColorAnimaAppWorkspaceDesignSystem
import SwiftUI

package struct RoleSwatchView: View {
    private static let slotWidth: CGFloat = 76

    let kind: RoleSwatchKind
    let title: String
    let color: Color
    let isSelected: Bool
    var selection: Binding<Color>?
    var onSelect: (() -> Void)?
    private let colorPanelPresenter: any RoleSwatchColorPanelPresenting

    package init(
        kind: RoleSwatchKind,
        title: String,
        color: Color,
        isSelected: Bool = false,
        selection: Binding<Color>? = nil,
        onSelect: (() -> Void)? = nil,
        colorPanelPresenter: any RoleSwatchColorPanelPresenting = NoOpRoleSwatchColorPanelPresenter.shared
    ) {
        self.kind = kind
        self.title = title
        self.color = color
        self.isSelected = isSelected
        self.selection = selection
        self.onSelect = onSelect
        self.colorPanelPresenter = colorPanelPresenter
    }

    private var displayedColor: Color {
        selection?.wrappedValue ?? color
    }

    private var interactionState: RoleSwatchInteractionState {
        RoleSwatchInteractionState(selection: selection, isSelected: isSelected)
    }

    package var body: some View {
        VStack(spacing: WorkspaceFoundation.Metrics.space2) {
            swatch
                .frame(maxWidth: .infinity, alignment: .center)

            Text(title)
                .font(.caption.weight(interactionState.labelWeight))
                .foregroundStyle(
                    interactionState.isSelected
                        ? WorkspaceFoundation.Foreground.primaryLabel
                        : WorkspaceFoundation.Foreground.secondaryLabel
                )
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
        }
        .frame(width: Self.slotWidth)
    }

    @ViewBuilder
    private var swatch: some View {
        let capsule = Capsule()
            .fill(displayedColor)
            .frame(width: 52, height: 18)
            .overlay {
                Capsule()
                    .stroke(
                        interactionState.isSelected
                            ? WorkspaceChromeStyle.Inspector.selectedSwatchStroke
                            : WorkspaceChromeStyle.Inspector.swatchStroke,
                        lineWidth: interactionState.strokeLineWidth
                    )
            }
            .accessibilityLabel(title)
            .accessibilityValue(interactionState.isSelected ? "Selected" : "Not selected")
            .simultaneousGesture(
                TapGesture(count: 1)
                    .onEnded {
                        handleSingleTap()
                    }
            )

        if interactionState.isEditable, let selection {
            capsule
                .accessibilityHint("Double-click to edit color")
                .simultaneousGesture(
                    TapGesture(count: 2)
                        .onEnded {
                            handleDoubleTap(selection: selection)
                        }
                )
        } else {
            capsule
        }
    }

    private func handleSingleTap() {
        onSelect?()
        guard let selection else {
            return
        }
        colorPanelPresenter.syncVisiblePanel(selection: selection)
    }

    private func handleDoubleTap(selection: Binding<Color>) {
        onSelect?()
        colorPanelPresenter.present(selection: selection)
    }
}
