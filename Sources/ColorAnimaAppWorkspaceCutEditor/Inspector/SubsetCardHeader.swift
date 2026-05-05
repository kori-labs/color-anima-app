import ColorAnimaAppWorkspaceApplication
import ColorAnimaAppWorkspaceDesignSystem
import SwiftUI

package struct SubsetCardHeader: View {
    let subset: ColorSystemSubset
    let isEditing: Bool
    let isHovered: Bool
    let deleteResetToken: AnyHashable
    @Binding var editingSubsetName: String
    let onSelectSubset: (UUID) -> Void
    let onStartRename: (ColorSystemSubset) -> Void
    let onCommitRename: (UUID) -> Void
    let onCancelRename: () -> Void
    let onRemoveSubset: (UUID) -> Void

    package var body: some View {
        let content = ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: WorkspaceFoundation.Metrics.space3) {
                titleBlock
                Spacer()

                if !isEditing {
                    deleteButton
                }
            }

            VStack(alignment: .leading, spacing: WorkspaceFoundation.Metrics.space2_5) {
                titleBlock

                if !isEditing {
                    HStack {
                        Spacer()
                        deleteButton
                    }
                }
            }
        }

        if isEditing {
            content
        } else {
            content
                .simultaneousGesture(
                    TapGesture(count: 2)
                        .onEnded {
                            onStartRename(subset)
                        }
                )
                .simultaneousGesture(
                    TapGesture(count: 1)
                        .onEnded {
                            onSelectSubset(subset.id)
                        }
                )
        }
    }

    @ViewBuilder
    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: WorkspaceFoundation.Metrics.space1) {
            if isEditing {
                InlineRenameField(
                    text: $editingSubsetName,
                    placeholder: "Subset name",
                    onCommit: { onCommitRename(subset.id) },
                    onCancel: onCancelRename
                )
            } else {
                Text(subset.name)
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Text("\(subset.palettes.count) status variants")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .contentShape(.rect)
    }

    private var deleteButton: some View {
        HoverDeleteConfirmButton(
            isVisible: isHovered,
            resetToken: deleteResetToken,
            onConfirm: { onRemoveSubset(subset.id) }
        )
    }
}
