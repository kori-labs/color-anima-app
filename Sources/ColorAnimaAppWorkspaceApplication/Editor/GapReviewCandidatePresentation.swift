import Foundation

public enum GapReviewCandidateState: String, Codable, Hashable, Sendable {
    case pending
    case acceptedSuggested
    case manualColorApplied
    case ignored
    case rejectedSuggestion
    case resolvedByRepaint

    public var displayTitle: String {
        switch self {
        case .pending:
            "Pending review"
        case .acceptedSuggested:
            "Accepted suggested color"
        case .manualColorApplied:
            "Manual color applied"
        case .ignored:
            "Ignored"
        case .rejectedSuggestion:
            "Suggestion rejected"
        case .resolvedByRepaint:
            "Resolved by repaint"
        }
    }
}

public struct GapReviewCandidatePresentation: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var area: Int
    public var pixelCount: Int
    public var nearestPaintedRegionID: UUID?
    public var confidence: Double
    public var suggestedColor: RGBAColor?
    public var reviewState: GapReviewCandidateState

    public init(
        id: UUID = UUID(),
        area: Int,
        pixelCount: Int,
        nearestPaintedRegionID: UUID? = nil,
        confidence: Double,
        suggestedColor: RGBAColor?,
        reviewState: GapReviewCandidateState
    ) {
        self.id = id
        self.area = area
        self.pixelCount = pixelCount
        self.nearestPaintedRegionID = nearestPaintedRegionID
        self.confidence = confidence
        self.suggestedColor = suggestedColor
        self.reviewState = reviewState
    }
}
