import ColorAnimaAppWorkspaceDesignSystem
import SwiftUI

package struct SubsetStatusRow: View {
    let model: SubsetStatusEditorModel
    let deleteResetToken: AnyHashable
    let editingStatusName: String?
    @Binding var draftStatusName: String
    let onSetActiveStatus: (String) -> Void
    let onStartRename: () -> Void
    let onCommitRename: () -> Void
    let onCancelRename: () -> Void
    let onRemoveStatus: () -> Void

    private var isEditing: Bool {
        editingStatusName != nil
    }

    package var body: some View {
        VStack(alignment: .leading, spacing: WorkspaceFoundation.Metrics.space2) {
            if isEditing {
                InlineRenameField(
                    text: $draftStatusName,
                    placeholder: "Status name",
                    onCommit: onCommitRename,
                    onCancel: onCancelRename
                )
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: WorkspaceFoundation.Metrics.space2_5) {
                        statusPicker
                        actionButtons
                    }

                    VStack(alignment: .leading, spacing: WorkspaceFoundation.Metrics.space2_5) {
                        statusPicker
                        HStack {
                            Spacer()
                            actionButtons
                        }
                    }
                }
            }
        }
    }

    private var statusPicker: some View {
        Picker(
            "Status",
            selection: Binding(
                get: { model.resolvedActiveStatusName },
                set: { onSetActiveStatus($0) }
            )
        ) {
            ForEach(model.selectedStatusNames, id: \.self) { statusName in
                Text(statusName).tag(statusName)
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()
    }

    private var actionButtons: some View {
        HStack(spacing: WorkspaceFoundation.Metrics.space2) {
            Button(action: onStartRename) {
                Image(systemName: "pencil")
                    .font(.caption.weight(.semibold))
                    .frame(width: 14, height: 14)
            }
            .buttonStyle(actionButtonStyle)
            .accessibilityLabel("Rename Status")

            if model.canRemoveActiveStatus {
                HoverDeleteConfirmButton(
                    isVisible: true,
                    resetToken: deleteResetToken,
                    onConfirm: onRemoveStatus
                )
            } else {
                Button(action: {}) {
                    Image(systemName: "trash")
                        .font(.caption.weight(.semibold))
                        .frame(width: 14, height: 14)
                }
                .buttonStyle(actionButtonStyle)
                .disabled(true)
                .accessibilityLabel("Delete Status")
                .accessibilityHint("Cannot delete the last status")
            }
        }
    }

    private var actionButtonStyle: ChromeButtonStyle {
        ChromeButtonStyle(
            horizontalPadding: WorkspaceFoundation.Metrics.compactControlPadding,
            verticalPadding: WorkspaceFoundation.Metrics.microSpace1_25,
            cornerRadius: WorkspaceFoundation.Metrics.compactControlCornerRadius,
            font: .caption.weight(.semibold),
            idleForegroundStyle: WorkspaceFoundation.Foreground.secondaryLabel,
            hoverForegroundStyle: WorkspaceFoundation.Foreground.primaryLabel
        )
    }
}
