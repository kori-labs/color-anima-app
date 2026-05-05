import ColorAnimaAppWorkspaceApplication
import ColorAnimaAppWorkspaceDesignSystem
import SwiftUI

package struct ConfidenceCandidateCardView: View {
    let row: FrameConfidenceRow

    package init(row: FrameConfidenceRow) {
        self.row = row
    }

    package var body: some View {
        VStack(alignment: .leading, spacing: WorkspaceFoundation.Metrics.space2_5) {
            headerRow

            if candidateRegions.isEmpty {
                Text("No candidate detail available.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(candidateRegions.prefix(3)) { regionRow in
                    CandidateRegionEntryView(regionRow: regionRow)
                }
            }
        }
    }

    private var headerRow: some View {
        HStack {
            Text(row.frameLabel)
                .font(.headline)
            Spacer()
            ReviewStateBadgeView(state: row.reviewState)
        }
    }

    private var candidateRegions: [RegionConfidenceRow] {
        row.regionResults
            .filter { $0.reviewState != .tracked }
            .sorted { $0.confidenceValue < $1.confidenceValue }
    }
}

private struct CandidateRegionEntryView: View {
    let regionRow: RegionConfidenceRow

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Text(regionRow.regionDisplayName)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: 4)

                Text(confidenceLabel)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(confidenceLabelColor)
            }

            if reasonCodes.isEmpty == false {
                reasonTagRow
            }
        }
        .padding(WorkspaceFoundation.Metrics.space2_5)
        .background(WorkspaceFoundation.Surface.cardFill, in: RoundedRectangle(cornerRadius: 8))
    }

    private var confidenceLabel: String {
        let percent = Int((regionRow.confidenceValue * 100).rounded())
        return "\(percent)%"
    }

    private var confidenceLabelColor: Color {
        switch regionRow.reviewState {
        case .tracked:
            .green
        case .reviewNeeded:
            .orange
        case .unresolved:
            .red
        }
    }

    private var reasonCodes: [TrackingReviewReasonCode] {
        regionRow.reasonCodes
    }

    private var reasonTagRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(reasonCodes, id: \.self) { code in
                    ReasonCodeTag(code: code)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ReasonCodeTag: View {
    let code: TrackingReviewReasonCode

    var body: some View {
        Text(label)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, WorkspaceFoundation.Metrics.microSpace1_75)
            .padding(.vertical, WorkspaceFoundation.Metrics.microSpace0_75)
            .background(WorkspaceFoundation.Surface.tagFill, in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(WorkspaceFoundation.Stroke.tagBorder, lineWidth: 0.5)
            }
    }

    private var label: String {
        switch code {
        case .lowMargin:
            "Low Margin"
        case .structuralConflict:
            "Structural Conflict"
        case .split:
            "Split"
        case .merge:
            "Merge"
        case .reappearance:
            "Reappearance"
        case .insufficientSupport:
            "Insufficient Support"
        case .anchorDisagreement:
            "Anchor Disagreement"
        }
    }
}
