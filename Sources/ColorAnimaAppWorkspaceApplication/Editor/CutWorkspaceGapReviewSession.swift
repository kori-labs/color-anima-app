import Foundation

public extension CutWorkspaceGapReviewFrameSession {
    var unresolvedCount: Int {
        candidates.lazy.filter { $0.reviewState == .pending }.count
    }

    var preflightSummary: CutWorkspaceTrackingPreflightSummary {
        var unresolvedGapCandidates = 0
        var unreviewedSuggestedCorrections = 0

        for candidate in candidates where candidate.reviewState == .pending {
            unresolvedGapCandidates += 1
            if candidate.suggestedColor != nil {
                unreviewedSuggestedCorrections += 1
            }
        }

        return CutWorkspaceTrackingPreflightSummary(
            unresolvedGapCandidates: unresolvedGapCandidates,
            unreviewedSuggestedCorrections: unreviewedSuggestedCorrections
        )
    }

    mutating func select(_ id: UUID?) {
        guard let id, candidates.contains(where: { $0.id == id }) else {
            selectedCandidateID = nil
            return
        }
        selectedCandidateID = id
    }

    @discardableResult
    mutating func advanceToNextPending(from id: UUID? = nil) -> UUID? {
        guard candidates.isEmpty == false else {
            selectedCandidateID = nil
            return nil
        }

        let pivotID = id ?? selectedCandidateID
        let startIndex: Int
        if let pivotID,
           let index = candidates.firstIndex(where: { $0.id == pivotID }) {
            startIndex = (index + 1) % candidates.count
        } else {
            startIndex = 0
        }

        for offset in 0..<candidates.count {
            let index = (startIndex + offset) % candidates.count
            if candidates[index].reviewState == .pending {
                selectedCandidateID = candidates[index].id
                return candidates[index].id
            }
        }

        selectedCandidateID = nil
        return nil
    }

    mutating func acceptSuggested(_ id: UUID) {
        mutate(id) { candidate in
            guard candidate.suggestedColor != nil else { return }
            candidate.reviewState = .acceptedSuggested
        }
    }

    mutating func applyManualColor(_ color: RGBAColor, for id: UUID) {
        mutate(id) { candidate in
            candidate.suggestedColor = color
            candidate.reviewState = .manualColorApplied
        }
    }

    mutating func ignore(_ id: UUID) {
        mutate(id) { candidate in
            candidate.reviewState = .ignored
        }
    }

    mutating func rejectSuggestion(_ id: UUID) {
        mutate(id) { candidate in
            candidate.reviewState = .rejectedSuggestion
        }
    }

    mutating func markResolvedByRepaint(_ id: UUID) {
        mutate(id) { candidate in
            candidate.reviewState = .resolvedByRepaint
        }
    }

    mutating func resolveSuggestedColors(
        regionColorByID lookup: (UUID) -> RGBAColor?
    ) {
        for index in candidates.indices {
            if candidates[index].suggestedColor != nil { continue }
            guard let regionID = candidates[index].nearestPaintedRegionID,
                  let color = lookup(regionID) else {
                continue
            }
            candidates[index].suggestedColor = color
        }
    }

    private mutating func mutate(
        _ id: UUID,
        _ body: (inout GapReviewCandidatePresentation) -> Void
    ) {
        guard let index = candidates.firstIndex(where: { $0.id == id }) else { return }
        body(&candidates[index])
    }
}
