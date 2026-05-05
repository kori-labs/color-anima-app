import ColorAnimaAppWorkspaceApplication
import ColorAnimaAppWorkspaceDesignSystem
import SwiftUI

package struct CutWorkspaceGapInspectorView: View {
    let candidate: GapReviewCandidatePresentation
    let onApplySuggested: () -> Void
    let onPickColor: () -> Void
    let onIgnore: () -> Void
    let onReject: () -> Void
    let onNext: () -> Void

    package init(
        candidate: GapReviewCandidatePresentation,
        onApplySuggested: @escaping () -> Void,
        onPickColor: @escaping () -> Void,
        onIgnore: @escaping () -> Void,
        onReject: @escaping () -> Void,
        onNext: @escaping () -> Void
    ) {
        self.candidate = candidate
        self.onApplySuggested = onApplySuggested
        self.onPickColor = onPickColor
        self.onIgnore = onIgnore
        self.onReject = onReject
        self.onNext = onNext
    }

    package var body: some View {
        VStack(alignment: .leading, spacing: WorkspaceFoundation.Metrics.space3) {
            header
            statsBlock
            evidenceBlock
            actionRow
        }
        .padding(WorkspaceFoundation.Metrics.space4)
        .frame(minWidth: 280)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: WorkspaceFoundation.Metrics.space1) {
            Text("Gap Review")
                .font(.title3.bold())
            Text(candidate.reviewState.displayTitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var statsBlock: some View {
        VStack(alignment: .leading, spacing: WorkspaceFoundation.Metrics.space1) {
            statsRow(label: "Area", value: "\(candidate.area) px")
            statsRow(label: "Pixel count", value: "\(candidate.pixelCount)")
            statsRow(label: "Confidence", value: String(format: "%.2f", candidate.confidence))
        }
    }

    @ViewBuilder
    private var evidenceBlock: some View {
        VStack(alignment: .leading, spacing: WorkspaceFoundation.Metrics.compactControlPadding) {
            Text("Suggested color")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: WorkspaceFoundation.Metrics.space2) {
                swatch(for: candidate.suggestedColor)
                Text(candidate.suggestedColor == nil ? "No suggestion" : "From nearest painted region")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var actionRow: some View {
        HStack(spacing: WorkspaceFoundation.Metrics.space2) {
            Button("Apply Suggested", action: onApplySuggested)
                .disabled(candidate.suggestedColor == nil)
            Button("Pick Color", action: onPickColor)
            Button("Ignore", action: onIgnore)
            Button("Reject", action: onReject)
            Spacer()
            Button("Next", action: onNext)
                .keyboardShortcut(.defaultAction)
        }
        .controlSize(.small)
    }

    private func statsRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .monospacedDigit()
        }
        .font(.callout)
    }

    @ViewBuilder
    private func swatch(for color: RGBAColor?) -> some View {
        if let color {
            RoundedRectangle(cornerRadius: WorkspaceFoundation.Metrics.microRadius)
                .fill(Color(red: color.red, green: color.green, blue: color.blue, opacity: color.alpha))
                .frame(width: 28, height: 18)
                .overlay(
                    RoundedRectangle(cornerRadius: WorkspaceFoundation.Metrics.microRadius)
                        .stroke(.secondary.opacity(WorkspaceFoundation.Metrics.dimSelectionOpacity), lineWidth: 0.5)
                )
        } else {
            RoundedRectangle(cornerRadius: WorkspaceFoundation.Metrics.microRadius)
                .stroke(.secondary.opacity(WorkspaceFoundation.Metrics.dimSelectionOpacity), style: StrokeStyle(lineWidth: 0.5, dash: [3, 2]))
                .frame(width: 28, height: 18)
        }
    }
}
