import ColorAnimaAppWorkspaceApplication
import ColorAnimaAppWorkspaceDesignSystem
import SwiftUI

package struct RunTrackingPreflightSheet: View {
    @Environment(\.dismiss) private var dismiss

    let summary: CutWorkspaceTrackingPreflightSummary
    let onReviewNow: () -> Void
    let onRunAnyway: () -> Void

    package init(
        summary: CutWorkspaceTrackingPreflightSummary,
        onReviewNow: @escaping () -> Void,
        onRunAnyway: @escaping () -> Void
    ) {
        self.summary = summary
        self.onReviewNow = onReviewNow
        self.onRunAnyway = onRunAnyway
    }

    package var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Color & Gap Review")
                    .font(.title3.bold())
                Text("Unresolved gap candidates may flow into tracking as false evidence. You can review them now, or run tracking anyway and revisit the candidates afterward.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 4) {
                summaryRow(
                    label: "Unresolved gap candidates",
                    value: summary.unresolvedGapCandidates
                )
                summaryRow(
                    label: "Unreviewed suggested corrections",
                    value: summary.unreviewedSuggestedCorrections
                )
            }
            .padding(.vertical, 4)

            HStack {
                Button("Review Now") {
                    onReviewNow()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)

                Spacer()

                Button("Run Tracking Anyway") {
                    onRunAnyway()
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
        }
        .padding(WorkspaceFoundation.Metrics.space6)
        .frame(minWidth: 360, idealWidth: 420)
    }

    private func summaryRow(label: String, value: Int) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(value)")
                .monospacedDigit()
                .fontWeight(.medium)
        }
        .font(.callout)
    }
}
