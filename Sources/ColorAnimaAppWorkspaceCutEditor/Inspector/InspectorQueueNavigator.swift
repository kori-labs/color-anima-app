import ColorAnimaAppWorkspaceApplication
import SwiftUI

package struct InspectorQueueNavigator: View {
    let state: TrackingQueueNavigatorPresentation
    let onNavigateToQueueItem: (Int) -> Void
    let onAccept: (Int) -> Void
    let onReassign: (Int) -> Void
    let onSkip: (Int) -> Void

    package init(
        state: TrackingQueueNavigatorPresentation,
        onNavigateToQueueItem: @escaping (Int) -> Void,
        onAccept: @escaping (Int) -> Void,
        onReassign: @escaping (Int) -> Void,
        onSkip: @escaping (Int) -> Void
    ) {
        self.state = state
        self.onNavigateToQueueItem = onNavigateToQueueItem
        self.onAccept = onAccept
        self.onReassign = onReassign
        self.onSkip = onSkip
    }

    package var body: some View {
        if let currentItem = state.currentItem {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Text("Review Queue")
                        .font(.headline)

                    Spacer(minLength: 0)

                    Button {
                        onNavigateToQueueItem(max(state.currentIndex - 1, 0))
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .buttonStyle(.bordered)
                    .disabled(!state.canGoBackward)
                    .accessibilityLabel("Previous Queue Item")

                    Text(positionSummary)
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .accessibilityLabel("Queue Position")
                        .accessibilityValue(positionSummary)

                    Button {
                        onNavigateToQueueItem(min(state.currentIndex + 1, max(0, state.totalCount - 1)))
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                    .buttonStyle(.bordered)
                    .disabled(!state.canGoForward)
                    .accessibilityLabel("Next Queue Item")
                }

                Text(title(for: currentItem))
                    .font(.callout.weight(.semibold))

                HStack(spacing: 8) {
                    ForEach(reasonBadges(for: currentItem), id: \.self) { reasonBadge in
                        Text(reasonBadge)
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(severityColor.opacity(0.12))
                            .foregroundStyle(severityColor)
                            .clipShape(.capsule)
                    }

                    if currentItem.isManualOverride {
                        Text("Manual")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.secondary.opacity(0.12))
                            .foregroundStyle(.secondary)
                            .clipShape(.capsule)
                    }

                    Spacer(minLength: 0)

                    if let confidenceLabel = confidenceLabel(for: currentItem) {
                        Text(confidenceLabel)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 8) {
                    Button("Accept") {
                        onAccept(state.currentIndex)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!state.canAccept)

                    Button("Reassign") {
                        onReassign(state.currentIndex)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!state.canReassign)

                    Button("Skip") {
                        onSkip(state.currentIndex)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!state.canSkip)

                    Spacer(minLength: 0)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var severityColor: Color {
        switch state.severity {
        case .reviewNeeded:
            .orange
        case .unresolved:
            .red
        }
    }

    private var positionSummary: String {
        "\(state.currentIndex + 1) / \(state.totalCount)"
    }

    private func title(for currentItem: TrackingQueueNavigatorItem) -> String {
        "Region \(currentItem.regionDisplayName) / Frame \(currentItem.frameOrderIndex + 1)"
    }

    private func reasonBadges(for currentItem: TrackingQueueNavigatorItem) -> [String] {
        currentItem.reasonCodes.map { reason in
            switch reason {
            case .lowMargin:
                "Low margin"
            case .structuralConflict:
                "Structural conflict"
            case .split:
                "Split"
            case .merge:
                "Merge"
            case .reappearance:
                "Reappearance"
            case .insufficientSupport:
                "Insufficient support"
            case .anchorDisagreement:
                "Anchor disagreement"
            }
        }
    }

    private func confidenceLabel(for currentItem: TrackingQueueNavigatorItem) -> String? {
        guard let confidenceValue = currentItem.confidenceValue else {
            return nil
        }
        return "\(Int((confidenceValue * 100).rounded()))%"
    }
}
