import ColorAnimaAppWorkspaceApplication
import ColorAnimaAppWorkspaceDesignSystem
import SwiftUI

package struct SubsetCardView: View {
    let subset: ColorSystemSubset
    let isSelected: Bool
    let deleteResetToken: AnyHashable
    let activeStatusName: String
    let selectedStatusNames: [String]
    let editingSubsetID: UUID?
    @Binding var editingSubsetName: String
    let onSelectSubset: (UUID) -> Void
    let onStartRename: (ColorSystemSubset) -> Void
    let onCommitRename: (UUID) -> Void
    let onCancelRename: () -> Void
    let onSetActiveStatus: (String) -> Void
    let onAddStatus: () -> Void
    let onRenameStatus: (String, String) -> Void
    let onRemoveStatus: () -> Void
    let onRemoveSubset: (UUID) -> Void
    let baseColorSelection: Binding<Color>?
    let highlightColorSelection: Binding<Color>?
    let shadowColorSelection: Binding<Color>?
    let highlightEnabledBinding: Binding<Bool>?
    let shadowEnabledBinding: Binding<Bool>?
    let colorPanelPresenter: any RoleSwatchColorPanelPresenting
    @State private var selectedSwatchKind: RoleSwatchKind = .base
    @State private var isHovered = false

    package init(
        subset: ColorSystemSubset,
        isSelected: Bool,
        deleteResetToken: AnyHashable,
        activeStatusName: String,
        selectedStatusNames: [String],
        editingSubsetID: UUID?,
        editingSubsetName: Binding<String>,
        onSelectSubset: @escaping (UUID) -> Void,
        onStartRename: @escaping (ColorSystemSubset) -> Void,
        onCommitRename: @escaping (UUID) -> Void,
        onCancelRename: @escaping () -> Void,
        onSetActiveStatus: @escaping (String) -> Void,
        onAddStatus: @escaping () -> Void,
        onRenameStatus: @escaping (String, String) -> Void,
        onRemoveStatus: @escaping () -> Void,
        onRemoveSubset: @escaping (UUID) -> Void,
        baseColorSelection: Binding<Color>?,
        highlightColorSelection: Binding<Color>?,
        shadowColorSelection: Binding<Color>?,
        highlightEnabledBinding: Binding<Bool>?,
        shadowEnabledBinding: Binding<Bool>?,
        colorPanelPresenter: any RoleSwatchColorPanelPresenting = NoOpRoleSwatchColorPanelPresenter.shared
    ) {
        self.subset = subset
        self.isSelected = isSelected
        self.deleteResetToken = deleteResetToken
        self.activeStatusName = activeStatusName
        self.selectedStatusNames = selectedStatusNames
        self.editingSubsetID = editingSubsetID
        _editingSubsetName = editingSubsetName
        self.onSelectSubset = onSelectSubset
        self.onStartRename = onStartRename
        self.onCommitRename = onCommitRename
        self.onCancelRename = onCancelRename
        self.onSetActiveStatus = onSetActiveStatus
        self.onAddStatus = onAddStatus
        self.onRenameStatus = onRenameStatus
        self.onRemoveStatus = onRemoveStatus
        self.onRemoveSubset = onRemoveSubset
        self.baseColorSelection = baseColorSelection
        self.highlightColorSelection = highlightColorSelection
        self.shadowColorSelection = shadowColorSelection
        self.highlightEnabledBinding = highlightEnabledBinding
        self.shadowEnabledBinding = shadowEnabledBinding
        self.colorPanelPresenter = colorPanelPresenter
    }

    private var isEditing: Bool {
        editingSubsetID == subset.id
    }

    private var palette: StatusPalette? {
        SubsetCardPaletteLookup.palette(in: subset, activeStatusName: activeStatusName)
    }

    private var baseCardContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            SubsetCardHeader(
                subset: subset,
                isEditing: isEditing,
                isHovered: isHovered,
                deleteResetToken: deleteResetToken,
                editingSubsetName: $editingSubsetName,
                onSelectSubset: onSelectSubset,
                onStartRename: onStartRename,
                onCommitRename: onCommitRename,
                onCancelRename: onCancelRename,
                onRemoveSubset: onRemoveSubset
            )

            if let palette {
                SubsetCardSwatchStrip(
                    subsetID: subset.id,
                    palette: palette,
                    isSelected: isSelected,
                    selectedSwatchKind: selectedSwatchKind,
                    baseColorSelection: baseColorSelection,
                    highlightColorSelection: highlightColorSelection,
                    shadowColorSelection: shadowColorSelection,
                    colorPanelPresenter: colorPanelPresenter,
                    onSelectSubset: onSelectSubset,
                    onSelectSwatch: { selectedSwatchKind = $0 }
                )
            }

            if isSelected {
                selectedEditor
            }
        }
        .padding(WorkspaceFoundation.Metrics.space3_5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .chromeSelectablePanelCard(isActive: isSelected || isHovered, cornerRadius: 16)
        .contentShape(.rect(cornerRadius: 16))
        .onHover { hovering in
            isHovered = hovering
        }
    }

    @ViewBuilder
    private var interactiveCardContent: some View {
        if isSelected || isEditing {
            baseCardContent.subsetCardDragInteraction(
                subset: subset,
                activeStatusName: activeStatusName,
                isEditing: isEditing
            )
        } else {
            baseCardContent
                .onTapGesture {
                    onSelectSubset(subset.id)
                }
                .subsetCardDragInteraction(
                    subset: subset,
                    activeStatusName: activeStatusName,
                    isEditing: isEditing
                )
        }
    }

    package var body: some View {
        interactiveCardContent
    }

    private var selectedEditor: some View {
        SubsetStatusEditor(
            activeStatusName: activeStatusName,
            selectedStatusNames: selectedStatusNames,
            deleteResetToken: deleteResetToken,
            onSetActiveStatus: onSetActiveStatus,
            onAddStatus: onAddStatus,
            onRenameStatus: onRenameStatus,
            onRemoveStatus: onRemoveStatus,
            highlightEnabledBinding: highlightEnabledBinding,
            shadowEnabledBinding: shadowEnabledBinding
        )
    }
}
