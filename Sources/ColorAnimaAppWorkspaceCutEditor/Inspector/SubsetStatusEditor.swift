import ColorAnimaAppWorkspaceDesignSystem
import SwiftUI

package struct SubsetStatusEditorModel: Equatable {
    let activeStatusName: String
    let selectedStatusNames: [String]

    var resolvedActiveStatusName: String {
        if selectedStatusNames.contains(activeStatusName) {
            return activeStatusName
        }
        return selectedStatusNames.first ?? ""
    }

    var canRemoveActiveStatus: Bool {
        selectedStatusNames.count > 1
    }

    var resetToken: String {
        ([resolvedActiveStatusName] + selectedStatusNames).joined(separator: "|")
    }
}

package struct SubsetStatusEditor: View {
    let activeStatusName: String
    let selectedStatusNames: [String]
    let deleteResetToken: AnyHashable
    let onSetActiveStatus: (String) -> Void
    let onAddStatus: () -> Void
    let onRenameStatus: (String, String) -> Void
    let onRemoveStatus: () -> Void
    let highlightEnabledBinding: Binding<Bool>?
    let shadowEnabledBinding: Binding<Bool>?

    @State private var editingStatusName: String?
    @State private var draftStatusName = ""

    private var model: SubsetStatusEditorModel {
        SubsetStatusEditorModel(
            activeStatusName: activeStatusName,
            selectedStatusNames: selectedStatusNames
        )
    }

    package var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Rectangle()
                .fill(WorkspaceChromeStyle.Inspector.sectionDivider)
                .frame(height: 1)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Status Variants")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Add Status", action: onAddStatus)
                        .buttonStyle(statusActionButtonStyle)
                }

                SubsetStatusRow(
                    model: model,
                    deleteResetToken: deleteResetToken,
                    editingStatusName: editingStatusName,
                    draftStatusName: $draftStatusName,
                    onSetActiveStatus: onSetActiveStatus,
                    onStartRename: startRename,
                    onCommitRename: commitRename,
                    onCancelRename: cancelRename,
                    onRemoveStatus: onRemoveStatus
                )
            }

            if let highlightEnabledBinding,
               let shadowEnabledBinding {
                Rectangle()
                    .fill(WorkspaceChromeStyle.Inspector.sectionDivider)
                    .frame(height: 1)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Legacy Fill Controls")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Toggle("Highlight Fill", isOn: highlightEnabledBinding)
                    Toggle("Shadow Fill", isOn: shadowEnabledBinding)
                }
            }
        }
        .onChange(of: model.resetToken) {
            cancelRename()
        }
    }

    private var statusActionButtonStyle: ChromeButtonStyle {
        ChromeButtonStyle(
            horizontalPadding: 10,
            verticalPadding: 6,
            cornerRadius: 10,
            font: .caption.weight(.semibold),
            idleForegroundStyle: WorkspaceFoundation.Foreground.secondaryLabel,
            hoverForegroundStyle: WorkspaceFoundation.Foreground.primaryLabel
        )
    }

    private func startRename() {
        editingStatusName = model.resolvedActiveStatusName
        draftStatusName = model.resolvedActiveStatusName
    }

    private func commitRename() {
        guard let editingStatusName else { return }
        let draftValue = draftStatusName
        cancelRename()
        onRenameStatus(editingStatusName, draftValue)
    }

    private func cancelRename() {
        editingStatusName = nil
        draftStatusName = ""
    }
}
