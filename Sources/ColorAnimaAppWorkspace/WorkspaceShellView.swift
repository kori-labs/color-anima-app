import ColorAnimaAppEngine
import ColorAnimaAppWorkspaceApplication
import ColorAnimaAppWorkspaceCutEditor
import ColorAnimaAppWorkspaceDesignSystem
import ColorAnimaAppWorkspaceProjectTree
import ColorAnimaAppWorkspaceShell
import SwiftUI

public struct WorkspaceShellView: View {
    private let startupState: WorkspaceState
    private let onRecheck: () -> Void

    @State private var host = WorkspaceHostModel()
    @State private var inspectorWidth: CGFloat = 380

    public init(state: WorkspaceState, onRecheck: @escaping () -> Void) {
        self.startupState = state
        self.onRecheck = onRecheck
    }

    public var body: some View {
        VStack(spacing: 0) {
            WorkspaceCommandBarView(
                canExportPreview: host.canExportPreview,
                isTrackingRunnable: host.isTrackingRunnable,
                isTrackingRunning: host.isTrackingRunning,
                hasTrackingResults: host.hasTrackingResults,
                trackingCutSummaryLabel: host.trackingCutSummaryLabel,
                trackingCancelSummaryLabel: host.trackingCancelSummaryLabel,
                trackingReadinessReason: host.trackingReadinessReason,
                extractionProgressLabel: kernelVersionLabel,
                onNewProject: host.newProject,
                onOpenProject: host.openProject,
                onSaveProject: host.saveProject,
                onRunTrackingPipeline: host.runTrackingPipeline,
                onRerunTrackingPipeline: host.rerunTrackingPipeline,
                onExportPreview: host.exportFrames,
                onExportReviewPreview: host.exportFrames,
                onExportPNGSequence: host.exportFrames
            )

            NavigationSplitView {
                ProjectTreeView(
                    rootNode: host.treeRoot,
                    selectedNodeID: host.selectedNodeID,
                    selectedNodeIDs: host.selectedNodeIDs,
                    selectionAnchorNodeID: host.selectionAnchorNodeID,
                    selectedNode: host.selectedNode,
                    onSelectNode: host.selectNode,
                    onMoveTreeNodes: { nodeIDs, targetNodeID, position in
                        host.moveTreeNodes(Set(nodeIDs), to: targetNodeID, position: position)
                    },
                    onRenameNode: { nodeID, name in
                        host.renameNode(nodeID, to: name)
                    },
                    onCreateSequence: host.createSequence,
                    onCreateScene: { sequenceID in
                        host.createScene(in: sequenceID)
                    },
                    onCreateCut: { sceneID in
                        host.createCut(in: sceneID)
                    },
                    onOpenProjectSettings: onRecheck,
                    onDeleteNode: host.deleteNode
                )
                .navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 360)
            } detail: {
                detailView
            }
        }
        .frame(minWidth: 960, minHeight: 640)
        .background(WorkspaceFoundation.Surface.surfaceFill)
    }

    @ViewBuilder
    private var detailView: some View {
        if host.selectedNode?.kind == .cut {
            WorkspaceDetailSplitView(
                inspectorWidth: $inspectorWidth,
                minimumLeadingWidth: 720,
                inspectorWidthRange: 340 ... 420,
                dividerColor: WorkspaceChromeStyle.workspacePanelDivider
            ) {
                CutWorkspaceCanvasView(model: host)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } trailing: {
                CutWorkspaceInspectorView(model: host)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            WorkspaceSelectionSummaryView(
                selectedNode: host.selectedNode,
                projectName: host.projectName,
                sequenceName: host.sequenceName,
                sceneName: host.sceneName,
                cutName: host.cutName
            )
        }
    }

    private var kernelVersionLabel: String? {
        guard let version = startupState.engineStatus.kernelVersion else { return nil }
        return "Kernel v\(version.description)"
    }
}
