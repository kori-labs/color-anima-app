import ColorAnimaAppWorkspaceApplication
import ColorAnimaAppWorkspaceDesignSystem
import SwiftUI

package struct ConfidenceTimelineView: View {
    let rows: [FrameConfidenceRow]
    let selectedFrameID: UUID?
    @Binding var filter: ConfidenceReviewFilter
    let onSelectFrame: (UUID) -> Void

    package init(
        rows: [FrameConfidenceRow],
        selectedFrameID: UUID?,
        filter: Binding<ConfidenceReviewFilter>,
        onSelectFrame: @escaping (UUID) -> Void
    ) {
        self.rows = rows
        self.selectedFrameID = selectedFrameID
        self._filter = filter
        self.onSelectFrame = onSelectFrame
    }

    package var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            headerRow
            filterPicker

            if filteredRows.isEmpty {
                emptyStateLabel
            } else {
                frameList
            }
        }
    }

    private var headerRow: some View {
        HStack {
            Text("Confidence Review")
                .font(.title3.bold())
            Spacer()
            if rows.isEmpty == false {
                Text("\(filteredRows.count) frame\(filteredRows.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var filterPicker: some View {
        Picker("Filter", selection: $filter) {
            ForEach(ConfidenceReviewFilter.allCases, id: \.self) { option in
                Text(option.label).tag(option)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }

    private var frameList: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(filteredRows) { row in
                ConfidenceFrameRowView(
                    row: row,
                    isSelected: row.frameID == selectedFrameID,
                    onTap: { onSelectFrame(row.frameID) }
                )
            }
        }
    }

    private var emptyStateLabel: some View {
        Text(emptyStateText)
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, WorkspaceFoundation.Metrics.space1)
    }

    private var filteredRows: [FrameConfidenceRow] {
        switch filter {
        case .all:
            rows
        case .reviewNeeded:
            rows.filter { $0.reviewState == .reviewNeeded }
        case .unresolved:
            rows.filter { $0.reviewState == .unresolved }
        }
    }

    private var emptyStateText: String {
        switch filter {
        case .all:
            "No tracked frames yet."
        case .reviewNeeded:
            "No frames need review."
        case .unresolved:
            "No unresolved frames."
        }
    }
}

private struct ConfidenceFrameRowView: View {
    let row: FrameConfidenceRow
    let isSelected: Bool
    let onTap: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            Text(row.frameLabel)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .leading)

            ConfidenceBarView(value: row.averageConfidence, reviewState: row.reviewState)

            Spacer(minLength: 4)

            ReviewStateBadgeView(state: row.reviewState)
        }
        .padding(.horizontal, WorkspaceFoundation.Metrics.space2_5)
        .padding(.vertical, WorkspaceFoundation.Metrics.microSpace1_75)
        .background(
            isSelected || isHovered
                ? Color.accentColor.opacity(isSelected ? 0.15 : 0.07)
                : Color.clear,
            in: RoundedRectangle(cornerRadius: 8)
        )
        .contentShape(.rect(cornerRadius: 8))
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            onTap()
        }
    }
}

private struct ConfidenceBarView: View {
    let value: Double
    let reviewState: ConfidenceReviewState

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.secondary.opacity(0.15))

                RoundedRectangle(cornerRadius: 3)
                    .fill(barColor)
                    .frame(width: geo.size.width * max(0.0, min(1.0, value)))
            }
        }
        .frame(height: 6)
    }

    private var barColor: Color {
        switch reviewState {
        case .tracked:
            .green
        case .reviewNeeded:
            .orange
        case .unresolved:
            .red
        }
    }
}

package struct ReviewStateBadgeView: View {
    let state: ConfidenceReviewState

    package init(state: ConfidenceReviewState) {
        self.state = state
    }

    package var body: some View {
        Text(label)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, WorkspaceFoundation.Metrics.compactControlPadding)
            .padding(.vertical, WorkspaceFoundation.Metrics.microSpace0_75)
            .background(backgroundColor.opacity(0.18), in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(foregroundColor.opacity(0.4), lineWidth: 0.5)
            }
    }

    private var label: String {
        switch state {
        case .tracked:
            "Tracked"
        case .reviewNeeded:
            "Review"
        case .unresolved:
            "Unresolved"
        }
    }

    private var foregroundColor: Color {
        switch state {
        case .tracked:
            .green
        case .reviewNeeded:
            .orange
        case .unresolved:
            .red
        }
    }

    private var backgroundColor: Color {
        foregroundColor
    }
}
