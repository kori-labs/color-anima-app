import Foundation

public struct SelectedRegionInspectorState {
    public let regionID: UUID
    public let displayName: String
    public let regionIDSummary: String
    public let centroidSummary: String
    public let boundsSummary: String
    public let assignmentSummary: String
    public let highlightSplitSummary: String?
    public let shadowSplitSummary: String?
    public let trackingStateSummary: String?
    public let trackingConfidenceSummary: String?
    public let trackingReasonSummary: String?
    public let trackingManualSummary: String?
    public let isTrackingAware: Bool
    public let assignActionTitle: String
    public let clearActionTitle: String
    public let canAssignToSelectedSubset: Bool
    public let canClearAssignment: Bool
    public let canInvertHighlightSplit: Bool
    public let canInvertShadowSplit: Bool
    public let canAcceptTracking: Bool
    public let canReassignTracking: Bool
    public let canClearTracking: Bool
    public let boundaryOffset: Int
    public let canEditBoundaryOffset: Bool

    public init(
        regionID: UUID,
        displayName: String,
        regionIDSummary: String,
        centroidSummary: String,
        boundsSummary: String,
        assignmentSummary: String,
        highlightSplitSummary: String?,
        shadowSplitSummary: String?,
        trackingStateSummary: String? = nil,
        trackingConfidenceSummary: String? = nil,
        trackingReasonSummary: String? = nil,
        trackingManualSummary: String? = nil,
        isTrackingAware: Bool = false,
        assignActionTitle: String = "Assign to Selected Subset",
        clearActionTitle: String = "Clear Assignment",
        canAssignToSelectedSubset: Bool,
        canClearAssignment: Bool,
        canInvertHighlightSplit: Bool,
        canInvertShadowSplit: Bool,
        canAcceptTracking: Bool = false,
        canReassignTracking: Bool = false,
        canClearTracking: Bool = false,
        boundaryOffset: Int = 0,
        canEditBoundaryOffset: Bool = false
    ) {
        self.regionID = regionID
        self.displayName = displayName
        self.regionIDSummary = regionIDSummary
        self.centroidSummary = centroidSummary
        self.boundsSummary = boundsSummary
        self.assignmentSummary = assignmentSummary
        self.highlightSplitSummary = highlightSplitSummary
        self.shadowSplitSummary = shadowSplitSummary
        self.trackingStateSummary = trackingStateSummary
        self.trackingConfidenceSummary = trackingConfidenceSummary
        self.trackingReasonSummary = trackingReasonSummary
        self.trackingManualSummary = trackingManualSummary
        self.isTrackingAware = isTrackingAware
        self.assignActionTitle = assignActionTitle
        self.clearActionTitle = clearActionTitle
        self.canAssignToSelectedSubset = canAssignToSelectedSubset
        self.canClearAssignment = canClearAssignment
        self.canInvertHighlightSplit = canInvertHighlightSplit
        self.canInvertShadowSplit = canInvertShadowSplit
        self.canAcceptTracking = canAcceptTracking
        self.canReassignTracking = canReassignTracking
        self.canClearTracking = canClearTracking
        self.boundaryOffset = boundaryOffset
        self.canEditBoundaryOffset = canEditBoundaryOffset
    }
}
