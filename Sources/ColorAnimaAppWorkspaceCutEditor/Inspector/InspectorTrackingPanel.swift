import ColorAnimaAppWorkspaceApplication
import SwiftUI

package struct InspectorTrackingPanel: View {
    let state: SelectedRegionInspectorState
    let onAccept: (Bool) -> Void
    let onReassign: (Bool) -> Void
    let onClear: () -> Void
    @State private var promoteToAnchor = false

    package init(
        state: SelectedRegionInspectorState,
        onAccept: @escaping (Bool) -> Void,
        onReassign: @escaping (Bool) -> Void,
        onClear: @escaping () -> Void
    ) {
        self.state = state
        self.onAccept = onAccept
        self.onReassign = onReassign
        self.onClear = onClear
    }

    package var body: some View {
        if hasTrackingDetails || state.isTrackingAware {
            VStack(alignment: .leading, spacing: 6) {
                if let trackingStateSummary = state.trackingStateSummary {
                    Text(trackingStateSummary)
                        .font(.callout.weight(.semibold))
                }

                if let trackingConfidenceSummary = state.trackingConfidenceSummary {
                    Text(trackingConfidenceSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let trackingReasonSummary = state.trackingReasonSummary {
                    Text("Reasons: \(trackingReasonSummary)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let trackingManualSummary = state.trackingManualSummary {
                    Text(trackingManualSummary)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                if state.isTrackingAware {
                    Divider()
                        .padding(.vertical, 2)

                    Toggle("Promote to anchor", isOn: $promoteToAnchor)
                        .font(.caption)

                    HStack(spacing: 8) {
                        Button("Accept") {
                            onAccept(promoteToAnchor)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!state.canAcceptTracking)

                        Button("Reassign") {
                            onReassign(promoteToAnchor)
                        }
                        .buttonStyle(.bordered)
                        .disabled(!state.canReassignTracking)

                        Button("Clear", role: .destructive) {
                            onClear()
                        }
                        .buttonStyle(.bordered)
                        .disabled(!state.canClearTracking)

                        Spacer(minLength: 0)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .id(state.regionID)
        }
    }

    private var hasTrackingDetails: Bool {
        state.trackingStateSummary != nil
            || state.trackingConfidenceSummary != nil
            || state.trackingReasonSummary != nil
            || state.trackingManualSummary != nil
    }
}
