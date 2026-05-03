import ColorAnimaAppWorkspaceApplication

package enum SelectedRegionSummaryLines {
    package struct Line: Equatable {
        package enum Kind: Equatable {
            case assignment
            case detail
        }

        package let text: String
        package let kind: Kind
    }

    package static func lines(for state: SelectedRegionInspectorState) -> [Line] {
        var lines: [Line] = [
            Line(text: state.assignmentSummary, kind: .assignment),
        ]

        if let highlightSplitSummary = state.highlightSplitSummary {
            lines.append(Line(text: highlightSplitSummary, kind: .detail))
        }

        if let shadowSplitSummary = state.shadowSplitSummary {
            lines.append(Line(text: shadowSplitSummary, kind: .detail))
        }

        if let trackingStateSummary = state.trackingStateSummary {
            lines.append(Line(text: trackingStateSummary, kind: .detail))
        }

        if let trackingConfidenceSummary = state.trackingConfidenceSummary {
            lines.append(Line(text: trackingConfidenceSummary, kind: .detail))
        }

        if let trackingReasonSummary = state.trackingReasonSummary {
            lines.append(Line(text: "Reasons: \(trackingReasonSummary)", kind: .detail))
        }

        if let trackingManualSummary = state.trackingManualSummary {
            lines.append(Line(text: trackingManualSummary, kind: .detail))
        }

        return lines
    }
}
