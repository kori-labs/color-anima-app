import ColorAnimaAppWorkspaceApplication
import ColorAnimaAppWorkspaceCutEditor
import ColorAnimaAppWorkspaceDesignSystem
import SwiftUI

struct CutWorkspaceFrameStripView: View {
    @Bindable var model: WorkspaceHostModel

    var body: some View {
        let frameItems = model.frameStripItems
        let allFrameIDs = model.frameStripItemIDs
        let selectedFrameIDs = model.selectedFrameIDs

        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Frames")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                HoverDeleteConfirmButton(
                    isVisible: model.canDeleteSelectedFrames,
                    resetToken: AnyHashable(selectedFrameIDs)
                ) {
                    model.deleteSelectedFrames()
                }
                .help(model.deleteSelectedFramesTitle)

                Text("\(frameItems.count) frame\(frameItems.count == 1 ? "" : "s")")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 0) {
                    ForEach(Array(frameItems.enumerated()), id: \.offset) { index, frame in
                        let frameID = allFrameIDs[index]
                        frameInsertionSlot(
                            target: WorkspaceFrameDropTarget(targetFrameID: frameID, position: .before),
                            allFrameIDs: allFrameIDs,
                            isLeadingEdge: index == 0
                        )
                        frameCard(
                            frame,
                            frameID: frameID,
                            allFrameIDs: allFrameIDs,
                            selectedFrameIDs: selectedFrameIDs
                        )
                    }

                    frameInsertionSlot(
                        target: WorkspaceFrameDropTarget(targetFrameID: nil, position: .append),
                        allFrameIDs: allFrameIDs,
                        isLeadingEdge: false
                    )

                    Button {
                        model.createFrame()
                    } label: {
                        VStack(alignment: .center, spacing: 8) {
                            Image(systemName: "plus")
                                .font(.headline.weight(.semibold))
                            Text("Add Frame")
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(.secondary)
                        .frame(width: 92, height: 84)
                        .background(WorkspaceChromeStyle.treeRowFill)
                        .overlay {
                            RoundedRectangle(
                                cornerRadius: WorkspaceFoundation.Metrics.frameCardCornerRadius,
                                style: .continuous
                            )
                                .strokeBorder(
                                    WorkspaceChromeStyle.workspacePanelDivider.opacity(0.75),
                                    style: StrokeStyle(lineWidth: 1, dash: [5, 4])
                                )
                        }
                        .clipShape(.rect(cornerRadius: WorkspaceFoundation.Metrics.frameCardCornerRadius))
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.hidden)
        }
        .padding(WorkspaceFoundation.Metrics.space3)
        .background(WorkspaceChromeStyle.overlayPanelFill)
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(WorkspaceChromeStyle.overlayPanelStroke, lineWidth: 1)
        }
        .clipShape(.rect(cornerRadius: 18))
    }

    private func frameCard(
        _ frame: FrameStripCardItem,
        frameID: UUID,
        allFrameIDs: [UUID],
        selectedFrameIDs: Set<UUID>
    ) -> some View {
        FrameStripCardView(
            item: frame,
            allFrameIDs: allFrameIDs,
            selectedFrameIDs: selectedFrameIDs,
            onSelect: { modifiers in
                model.selectFrame(frameID, modifiers: modifiers)
            },
            onAddReference: { model.addReferenceFrame(frameID) },
            onMakeActiveReference: { model.setActiveReferenceFrame(frameID) },
            onRemoveReference: { model.removeReferenceFrame(frameID) }
        )
    }

    private func frameInsertionSlot(
        target: WorkspaceFrameDropTarget,
        allFrameIDs: [UUID],
        isLeadingEdge: Bool
    ) -> some View {
        FrameStripInsertionSlot(
            target: target,
            allFrameIDs: allFrameIDs,
            draggedFrameIDs: { FrameStripDragContext.draggedFrameIDs },
            onMoveFrames: { moveTarget in
                model.moveSelectedFrames(to: moveTarget)
            },
            width: isLeadingEdge ? 10 : 14
        )
    }
}
