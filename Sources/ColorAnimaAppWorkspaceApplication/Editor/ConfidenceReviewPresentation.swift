import Foundation

public enum ConfidenceReviewState: String, Codable, CaseIterable, Hashable, Sendable {
    case tracked
    case reviewNeeded
    case unresolved
}

public struct FrameConfidenceRow: Hashable, Equatable, Sendable, Identifiable {
    public var id: UUID { frameID }
    public var frameID: UUID
    public var frameLabel: String
    public var orderIndex: Int
    public var reviewState: ConfidenceReviewState
    public var averageConfidence: Double
    public var regionResults: [RegionConfidenceRow]

    public init(
        frameID: UUID,
        frameLabel: String,
        orderIndex: Int,
        reviewState: ConfidenceReviewState,
        averageConfidence: Double,
        regionResults: [RegionConfidenceRow]
    ) {
        self.frameID = frameID
        self.frameLabel = frameLabel
        self.orderIndex = orderIndex
        self.reviewState = reviewState
        self.averageConfidence = max(0.0, min(1.0, averageConfidence))
        self.regionResults = regionResults
    }
}

public struct RegionConfidenceRow: Hashable, Equatable, Sendable, Identifiable {
    public var id: UUID { regionID }
    public var regionID: UUID
    public var regionDisplayName: String
    public var confidenceValue: Double
    public var reviewState: ConfidenceReviewState
    public var reasonCodes: [TrackingReviewReasonCode]

    public init(
        regionID: UUID,
        regionDisplayName: String,
        confidenceValue: Double,
        reviewState: ConfidenceReviewState,
        reasonCodes: [TrackingReviewReasonCode]
    ) {
        self.regionID = regionID
        self.regionDisplayName = regionDisplayName
        self.confidenceValue = max(0.0, min(1.0, confidenceValue))
        self.reviewState = reviewState
        self.reasonCodes = reasonCodes
    }
}

public enum ConfidenceReviewFilter: String, CaseIterable, Hashable, Sendable {
    case all
    case reviewNeeded
    case unresolved

    public var label: String {
        switch self {
        case .all:
            "All"
        case .reviewNeeded:
            "Review Needed"
        case .unresolved:
            "Unresolved"
        }
    }
}
