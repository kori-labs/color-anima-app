import Foundation

public struct CutWorkspaceTrackingPreflightSummary: Hashable, Sendable {
    public let unresolvedGapCandidates: Int
    public let unreviewedSuggestedCorrections: Int

    public init(
        unresolvedGapCandidates: Int,
        unreviewedSuggestedCorrections: Int
    ) {
        self.unresolvedGapCandidates = unresolvedGapCandidates
        self.unreviewedSuggestedCorrections = unreviewedSuggestedCorrections
    }

    public var hasUnresolvedReviewState: Bool {
        unresolvedGapCandidates > 0
    }

    public static func aggregate<S: Sequence>(
        sessions: S
    ) -> CutWorkspaceTrackingPreflightSummary? where S.Element == CutWorkspaceGapReviewFrameSession {
        var unresolvedGapCandidates = 0
        var unreviewedSuggestedCorrections = 0
        var sawSession = false

        for session in sessions {
            sawSession = true
            for candidate in session.candidates where candidate.reviewState == .pending {
                unresolvedGapCandidates += 1
                if candidate.suggestedColor != nil {
                    unreviewedSuggestedCorrections += 1
                }
            }
        }

        guard sawSession else { return nil }
        return CutWorkspaceTrackingPreflightSummary(
            unresolvedGapCandidates: unresolvedGapCandidates,
            unreviewedSuggestedCorrections: unreviewedSuggestedCorrections
        )
    }
}
