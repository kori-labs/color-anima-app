import ColorAnimaAppWorkspaceApplication
import ColorAnimaAppWorkspaceCutEditor
import ColorAnimaAppWorkspaceDesignSystem
import SwiftUI

struct CutWorkspaceHeaderView: View {
    @Bindable var model: WorkspaceHostModel
    let onImportAsset: (CutAssetKind) -> Void
    let onImportTriSequence: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 16) {
                    workspaceTitleBlock
                    Spacer(minLength: 20)
                    workspaceLayerToggleRow
                }

                VStack(alignment: .leading, spacing: 12) {
                    workspaceTitleBlock
                    workspaceLayerToggleScroller
                }
            }

            workspaceImportBadgeScroller
        }
    }

    private var workspaceTitleBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Cut Workspace")
                .font(.title2.bold())
            Text("\(model.projectName) / \(model.sequenceName) / \(model.sceneName) / \(model.cutName)")
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            Text("Current Frame: \(model.currentFrameName)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var workspaceLayerToggleRow: some View {
        HStack(spacing: 8) {
            Toggle("Base Fill", isOn: model.layerVisibilityBinding(\.showBaseOverlay))
            Toggle("Outline", isOn: model.layerVisibilityBinding(\.showOutline))
            Toggle("Highlight", isOn: model.layerVisibilityBinding(\.showHighlightLine))
            Toggle("Shadow", isOn: model.layerVisibilityBinding(\.showShadowLine))
            Toggle("Debug Overlay", isOn: $model.isRegionDebugOverlayEnabled)
        }
        .toggleStyle(.button)
    }

    private var workspaceLayerToggleScroller: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            workspaceLayerToggleRow
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
    }

    private var workspaceImportBadgeScroller: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                importTriSequenceBadge
                importBadge(title: "Outline", artwork: model.outlineArtwork, action: { onImportAsset(.outline) })
                importBadge(title: "Highlight Line", artwork: model.highlightLineArtwork, action: { onImportAsset(.highlightLine) })
                importBadge(title: "Shadow Line", artwork: model.shadowLineArtwork, action: { onImportAsset(.shadowLine) })
                extractionStatusBadge
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
    }

    private func importBadge(title: String, artwork: ImportedArtwork?, action: @escaping () -> Void) -> some View {
        let statusColor = artwork == nil ? Color.orange : Color.green

        return Button(action: action) {
            statusBadgeLabel(title: title, statusColor: statusColor)
        }
        .buttonStyle(.plain)
    }

    private var extractionStatusBadge: some View {
        Button {
            Task {
                await model.extractRegionsWithFeedback()
            }
        } label: {
            statusBadgeLabel(title: model.extractionActionTitle, statusColor: extractionStatusColor)
        }
        .buttonStyle(.plain)
        .disabled(!model.canTriggerExtraction || model.isExtractingRegions)
    }

    private var extractionStatusColor: Color {
        switch model.extractionStatus {
        case .idle:
            WorkspaceChromeStyle.treeMetaLabel
        case .running:
            .orange
        case .done:
            .green
        }
    }

    private func statusBadgeLabel(title: String, statusColor: Color) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            Text(title)
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, WorkspaceFoundation.Metrics.space2_5)
        .padding(.vertical, WorkspaceFoundation.Metrics.microSpace1_75)
        .background(WorkspaceChromeStyle.badgeFill)
        .overlay {
            Capsule()
                .strokeBorder(statusColor.opacity(0.32), lineWidth: 1)
        }
        .clipShape(.capsule)
    }

    private var importTriSequenceBadge: some View {
        Button(action: onImportTriSequence) {
            statusBadgeLabel(title: "Import Sequence", statusColor: .blue)
        }
        .buttonStyle(.plain)
    }
}
