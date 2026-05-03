import CoreGraphics
import Foundation

public enum SelectedRegionSplitDecision: String, Codable, Hashable, Sendable {
    case normal
    case inverted
}

public struct SelectedRegionAssignment: Codable, Hashable, Equatable, Sendable {
    public var groupID: UUID
    public var subsetID: UUID
    public var highlightSplitDecision: SelectedRegionSplitDecision
    public var shadowSplitDecision: SelectedRegionSplitDecision

    public init(
        groupID: UUID,
        subsetID: UUID,
        highlightSplitDecision: SelectedRegionSplitDecision = .normal,
        shadowSplitDecision: SelectedRegionSplitDecision = .normal
    ) {
        self.groupID = groupID
        self.subsetID = subsetID
        self.highlightSplitDecision = highlightSplitDecision
        self.shadowSplitDecision = shadowSplitDecision
    }
}

public struct SelectedRegionInspectorRegion: Identifiable, Hashable, Equatable, Sendable {
    public var id: UUID
    public var displayName: String
    public var centroid: CGPoint
    public var bounds: CGRect
    public var assignment: SelectedRegionAssignment?
    public var isBackgroundCandidate: Bool
    public var boundaryOffset: Int

    public init(
        id: UUID = UUID(),
        displayName: String,
        centroid: CGPoint,
        bounds: CGRect,
        assignment: SelectedRegionAssignment? = nil,
        isBackgroundCandidate: Bool = false,
        boundaryOffset: Int = 0
    ) {
        self.id = id
        self.displayName = displayName
        self.centroid = centroid
        self.bounds = bounds
        self.assignment = assignment
        self.isBackgroundCandidate = isBackgroundCandidate
        self.boundaryOffset = boundaryOffset
    }
}

public struct SelectedRegionTrackingRecord: Hashable, Equatable, Sendable {
    public var state: ConfidenceReviewState
    public var confidenceValue: Double?
    public var reasonCodes: [TrackingReviewReasonCode]
    public var isManualCorrection: Bool
    public var hasResolvedAssignment: Bool

    public init(
        state: ConfidenceReviewState,
        confidenceValue: Double? = nil,
        reasonCodes: [TrackingReviewReasonCode] = [],
        isManualCorrection: Bool = false,
        hasResolvedAssignment: Bool = false
    ) {
        self.state = state
        self.confidenceValue = confidenceValue
        self.reasonCodes = reasonCodes
        self.isManualCorrection = isManualCorrection
        self.hasResolvedAssignment = hasResolvedAssignment
    }
}

public enum SelectedRegionInspectorStateCoordinator {
    public static func makeState(
        region: SelectedRegionInspectorRegion?,
        groups: [ColorSystemGroup],
        selectedSubsetID: UUID?,
        trackingRecord: SelectedRegionTrackingRecord? = nil
    ) -> SelectedRegionInspectorState? {
        guard let region else {
            return nil
        }

        let assignmentSummary: String
        let highlightSplitSummary: String?
        let shadowSplitSummary: String?
        let hasAssignment = region.assignment != nil

        if let assignment = region.assignment,
           let group = groups.first(where: { $0.id == assignment.groupID }),
           let subset = group.subsets.first(where: { $0.id == assignment.subsetID }) {
            assignmentSummary = "Assigned to \(group.name) / \(subset.name)"
            highlightSplitSummary = splitSummary(
                prefix: "Highlight Split",
                decision: assignment.highlightSplitDecision
            )
            shadowSplitSummary = splitSummary(
                prefix: "Shadow Split",
                decision: assignment.shadowSplitDecision
            )
        } else if region.isBackgroundCandidate {
            assignmentSummary = "Background candidate"
            highlightSplitSummary = nil
            shadowSplitSummary = nil
        } else {
            assignmentSummary = "Not assigned yet"
            highlightSplitSummary = nil
            shadowSplitSummary = nil
        }

        let isTrackingAware = trackingRecord != nil
        let assignActionTitle = isTrackingAware ? "Reassign to Selected Subset" : "Assign to Selected Subset"
        let clearActionTitle = isTrackingAware ? "Mark Unresolved" : "Clear Assignment"

        return SelectedRegionInspectorState(
            regionID: region.id,
            displayName: region.displayName,
            regionIDSummary: String(region.id.uuidString.prefix(8)),
            centroidSummary: "\(Int(region.centroid.x.rounded())), \(Int(region.centroid.y.rounded()))",
            boundsSummary: "\(Int(region.bounds.origin.x)), \(Int(region.bounds.origin.y)) / \(Int(region.bounds.width))x\(Int(region.bounds.height))",
            assignmentSummary: assignmentSummary,
            highlightSplitSummary: highlightSplitSummary,
            shadowSplitSummary: shadowSplitSummary,
            trackingStateSummary: trackingRecord.map { trackingSummary(for: $0.state) },
            trackingConfidenceSummary: trackingRecord.flatMap { confidenceSummary(for: $0.confidenceValue) },
            trackingReasonSummary: trackingRecord.flatMap { reasonSummary(for: $0.reasonCodes) },
            trackingManualSummary: trackingRecord?.isManualCorrection == true
                ? "Manual correction preserved"
                : nil,
            isTrackingAware: isTrackingAware,
            assignActionTitle: assignActionTitle,
            clearActionTitle: clearActionTitle,
            canAssignToSelectedSubset: selectedSubsetID != nil,
            canClearAssignment: hasAssignment || isTrackingAware,
            canInvertHighlightSplit: hasAssignment,
            canInvertShadowSplit: hasAssignment,
            canAcceptTracking: canAcceptTracking(trackingRecord),
            canReassignTracking: trackingRecord != nil
                && trackingRecord?.isManualCorrection == false
                && selectedSubsetID != nil,
            canClearTracking: trackingRecord != nil,
            boundaryOffset: region.boundaryOffset,
            canEditBoundaryOffset: region.isBackgroundCandidate == false
        )
    }

    private static func canAcceptTracking(_ record: SelectedRegionTrackingRecord?) -> Bool {
        guard let record, record.isManualCorrection == false else {
            return false
        }
        return record.hasResolvedAssignment
    }

    private static func splitSummary(
        prefix: String,
        decision: SelectedRegionSplitDecision
    ) -> String {
        switch decision {
        case .normal:
            return "\(prefix): Normal"
        case .inverted:
            return "\(prefix): Inverted"
        }
    }

    private static func trackingSummary(for state: ConfidenceReviewState) -> String {
        switch state {
        case .tracked:
            return "Tracking: Tracked"
        case .reviewNeeded:
            return "Tracking: Review Needed"
        case .unresolved:
            return "Tracking: Unresolved"
        }
    }

    private static func confidenceSummary(for confidenceValue: Double?) -> String? {
        confidenceValue.map { "Confidence \(Int(($0 * 100).rounded()))%" }
    }

    private static func reasonSummary(for reasonCodes: [TrackingReviewReasonCode]) -> String? {
        guard reasonCodes.isEmpty == false else {
            return nil
        }

        return reasonCodes
            .sorted { $0.rawValue < $1.rawValue }
            .map(reasonLabel(for:))
            .joined(separator: ", ")
    }

    private static func reasonLabel(for reason: TrackingReviewReasonCode) -> String {
        switch reason {
        case .lowMargin:
            return "Low margin"
        case .structuralConflict:
            return "Structural conflict"
        case .split:
            return "Split"
        case .merge:
            return "Merge"
        case .reappearance:
            return "Reappearance"
        case .insufficientSupport:
            return "Insufficient support"
        case .anchorDisagreement:
            return "Anchor disagreement"
        }
    }
}
