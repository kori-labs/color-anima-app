import ColorAnimaAppWorkspaceDesignSystem
import SwiftUI

private enum WorkspaceCommandBarMetrics {
    static let height: CGFloat = 58
}

package struct WorkspaceCommandBarView: View {
    let canExportPreview: Bool
    let isTrackingRunnable: Bool
    let isTrackingRunning: Bool
    let hasTrackingResults: Bool
    let trackingCutSummaryLabel: String?
    let trackingCancelSummaryLabel: String?
    let trackingReadinessReason: String?
    let extractionProgressLabel: String?
    let accessory: AnyView?
    let onNewProject: () -> Void
    let onOpenProject: () -> Void
    let onSaveProject: () -> Void
    let onRunTrackingPipeline: () -> Void
    let onRerunTrackingPipeline: () -> Void
    let onExportPreview: () -> Void
    let onExportReviewPreview: () -> Void
    let onExportPNGSequence: () -> Void

    package init(
        canExportPreview: Bool,
        isTrackingRunnable: Bool = false,
        isTrackingRunning: Bool = false,
        hasTrackingResults: Bool = false,
        trackingCutSummaryLabel: String? = nil,
        trackingCancelSummaryLabel: String? = nil,
        trackingReadinessReason: String? = nil,
        extractionProgressLabel: String? = nil,
        accessory: AnyView? = nil,
        onNewProject: @escaping () -> Void,
        onOpenProject: @escaping () -> Void,
        onSaveProject: @escaping () -> Void,
        onRunTrackingPipeline: @escaping () -> Void = {},
        onRerunTrackingPipeline: @escaping () -> Void = {},
        onExportPreview: @escaping () -> Void,
        onExportReviewPreview: @escaping () -> Void,
        onExportPNGSequence: @escaping () -> Void
    ) {
        self.canExportPreview = canExportPreview
        self.isTrackingRunnable = isTrackingRunnable
        self.isTrackingRunning = isTrackingRunning
        self.hasTrackingResults = hasTrackingResults
        self.trackingCutSummaryLabel = trackingCutSummaryLabel
        self.trackingCancelSummaryLabel = trackingCancelSummaryLabel
        self.trackingReadinessReason = trackingReadinessReason
        self.extractionProgressLabel = extractionProgressLabel
        self.accessory = accessory
        self.onNewProject = onNewProject
        self.onOpenProject = onOpenProject
        self.onSaveProject = onSaveProject
        self.onRunTrackingPipeline = onRunTrackingPipeline
        self.onRerunTrackingPipeline = onRerunTrackingPipeline
        self.onExportPreview = onExportPreview
        self.onExportReviewPreview = onExportReviewPreview
        self.onExportPNGSequence = onExportPNGSequence
    }

    package var body: some View {
        let trackingActionDisabled = !isTrackingRunnable || isTrackingRunning
        let showsTrackingSummary = trackingCutSummaryLabel != nil && hasTrackingResults

        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                Button("New Project", action: onNewProject)
                    .buttonStyle(.bordered)

                Button("Open Project", action: onOpenProject)
                    .buttonStyle(.bordered)

                Button("Save Project", action: onSaveProject)
                    .buttonStyle(.borderedProminent)

                Divider()
                    .frame(height: 24)

                // `extractionProgressLabel` shows the frame-count summary while
                // longer-running action states are surfaced by WorkspaceStatusStrip.
                if let progress = extractionProgressLabel {
                    Text(progress)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                if hasTrackingResults {
                    Button("Re-run Tracking", action: onRerunTrackingPipeline)
                        .buttonStyle(.borderedProminent)
                        .disabled(isTrackingRunning)
                } else {
                    if let reason = trackingReadinessReason, !reason.isEmpty {
                        Button("Run Tracking", action: onRunTrackingPipeline)
                            .buttonStyle(.borderedProminent)
                            .disabled(trackingActionDisabled)
                            .help(reason)

                        Text(reason)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    } else {
                        Button("Run Tracking", action: onRunTrackingPipeline)
                            .buttonStyle(.borderedProminent)
                            .disabled(trackingActionDisabled)
                    }
                }

                if let trackingCutSummaryLabel, showsTrackingSummary {
                    Text(trackingCutSummaryLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let trackingCancelSummaryLabel {
                    Text(trackingCancelSummaryLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Divider()
                    .frame(height: 24)

                Button("Export Preview", action: onExportPreview)
                    .buttonStyle(.bordered)
                    .disabled(!canExportPreview)

                Button("Export Review PNG", action: onExportReviewPreview)
                    .buttonStyle(.bordered)
                    .disabled(!canExportPreview)

                Button("Export PNG Sequence", action: onExportPNGSequence)
                    .buttonStyle(.bordered)
                    .disabled(!canExportPreview)

                if let accessory {
                    accessory
                }
            }
            .padding(.horizontal, WorkspaceFoundation.Metrics.space4)
            .padding(.vertical, WorkspaceFoundation.Metrics.space3)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
        .frame(
            maxWidth: .infinity,
            minHeight: WorkspaceCommandBarMetrics.height,
            maxHeight: WorkspaceCommandBarMetrics.height,
            alignment: .leading
        )
        .background(Color.clear)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(WorkspaceChromeStyle.commandBarBorder)
                .frame(height: 1)
        }
    }
}
