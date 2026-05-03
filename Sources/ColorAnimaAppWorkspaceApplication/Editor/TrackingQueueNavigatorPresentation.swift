import Foundation

public enum TrackingReviewReasonCode: String, Codable, CaseIterable, Hashable, Sendable {
    case lowMargin
    case structuralConflict
    case split
    case merge
    case reappearance
    case insufficientSupport
    case anchorDisagreement
}

public struct TrackingQueueNavigatorItem: Hashable, Equatable, Sendable {
    public var frameID: UUID
    public var regionID: UUID
    public var regionDisplayName: String
    public var frameOrderIndex: Int
    public var confidenceValue: Double?
    public var reasonCodes: [TrackingReviewReasonCode]
    public var isManualOverride: Bool

    public init(
        frameID: UUID,
        regionID: UUID,
        regionDisplayName: String,
        frameOrderIndex: Int,
        confidenceValue: Double? = nil,
        reasonCodes: [TrackingReviewReasonCode] = [],
        isManualOverride: Bool = false
    ) {
        self.frameID = frameID
        self.regionID = regionID
        self.regionDisplayName = regionDisplayName
        self.frameOrderIndex = frameOrderIndex
        self.confidenceValue = confidenceValue
        self.reasonCodes = reasonCodes
        self.isManualOverride = isManualOverride
    }
}

public struct TrackingQueueNavigatorPresentation: Hashable, Equatable, Sendable {
    public enum Severity: String, Hashable, Sendable {
        case reviewNeeded
        case unresolved
    }

    public var frameID: UUID
    public var regionID: UUID
    public var currentIndex: Int
    public var totalCount: Int
    public var currentItem: TrackingQueueNavigatorItem?
    public var items: [TrackingQueueNavigatorItem]
    public var severity: Severity
    public var canGoBackward: Bool
    public var canGoForward: Bool
    public var canAccept: Bool
    public var canReassign: Bool
    public var canSkip: Bool

    public init(
        frameID: UUID,
        regionID: UUID,
        currentIndex: Int,
        totalCount: Int,
        currentItem: TrackingQueueNavigatorItem?,
        items: [TrackingQueueNavigatorItem],
        severity: Severity,
        canGoBackward: Bool,
        canGoForward: Bool,
        canAccept: Bool,
        canReassign: Bool,
        canSkip: Bool
    ) {
        self.frameID = frameID
        self.regionID = regionID
        self.currentIndex = max(0, currentIndex)
        self.totalCount = max(0, totalCount)
        self.currentItem = currentItem
        self.items = items
        self.severity = severity
        self.canGoBackward = canGoBackward
        self.canGoForward = canGoForward
        self.canAccept = canAccept
        self.canReassign = canReassign
        self.canSkip = canSkip
    }
}
