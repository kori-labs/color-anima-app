import Foundation

package struct FrameStripProjectionInput: Hashable, Identifiable, Sendable {
    package let id: UUID
    let orderIndex: Int
    let frameLabel: String?
    let displayFilename: String?
    let isCurrent: Bool
    let isSelected: Bool
    let isIncludedReference: Bool
    let isActiveReference: Bool
    let hasExtractedRegions: Bool
    let trackingState: FrameStripTrackingBadgeState?
    let trackingConfidence: Double?

    package init(
        id: UUID,
        orderIndex: Int,
        frameLabel: String? = nil,
        displayFilename: String? = nil,
        isCurrent: Bool = false,
        isSelected: Bool = false,
        isIncludedReference: Bool = false,
        isActiveReference: Bool = false,
        hasExtractedRegions: Bool = false,
        trackingState: FrameStripTrackingBadgeState? = nil,
        trackingConfidence: Double? = nil
    ) {
        self.id = id
        self.orderIndex = orderIndex
        self.frameLabel = frameLabel
        self.displayFilename = displayFilename
        self.isCurrent = isCurrent
        self.isSelected = isSelected
        self.isIncludedReference = isIncludedReference
        self.isActiveReference = isActiveReference
        self.hasExtractedRegions = hasExtractedRegions
        self.trackingState = trackingState
        self.trackingConfidence = trackingConfidence
    }
}

package enum FrameStripProjection {
    package static func cardItems(
        from frames: [FrameStripProjectionInput]
    ) -> [FrameStripCardItem] {
        frames
            .sorted {
                if $0.orderIndex == $1.orderIndex {
                    return $0.id.uuidString < $1.id.uuidString
                }
                return $0.orderIndex < $1.orderIndex
            }
            .map(cardItem)
    }

    private static func cardItem(
        for frame: FrameStripProjectionInput
    ) -> FrameStripCardItem {
        let displayFilename = frame.displayFilename?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedDisplayFilename: String
        let isDisplayFilenamePlaceholder: Bool
        if let displayFilename, displayFilename.isEmpty == false {
            resolvedDisplayFilename = displayFilename
            isDisplayFilenamePlaceholder = false
        } else {
            resolvedDisplayFilename = "No artwork"
            isDisplayFilenamePlaceholder = true
        }
        let isReference = frame.isIncludedReference
            || frame.isActiveReference
            || frame.trackingState == .reference

        return FrameStripCardItem(
            id: frame.id,
            frameLabel: frame.frameLabel ?? defaultFrameLabel(for: frame.orderIndex),
            displayFilename: resolvedDisplayFilename,
            isDisplayFilenamePlaceholder: isDisplayFilenamePlaceholder,
            isCurrent: frame.isCurrent,
            isSelected: frame.isSelected,
            isIncludedReference: frame.isIncludedReference,
            isActiveReference: frame.isActiveReference,
            showsPersistentReferenceAction: frame.hasExtractedRegions && isReference == false,
            trackingBadge: trackingBadge(for: frame)
        )
    }

    private static func trackingBadge(
        for frame: FrameStripProjectionInput
    ) -> FrameStripTrackingBadge? {
        let state = frame.isIncludedReference || frame.isActiveReference
            ? FrameStripTrackingBadgeState.reference
            : frame.trackingState

        guard let state else {
            return frame.hasExtractedRegions
                ? nil
                : FrameStripTrackingBadge(state: .needsExtraction, tint: .gray)
        }

        let confidencePercent = frame.trackingConfidence.map {
            Int(($0 * 100).rounded())
        }

        switch state {
        case .reference:
            return FrameStripTrackingBadge(state: .reference, label: "Ref", tint: .green)
        case .tracked:
            return FrameStripTrackingBadge(
                state: .tracked,
                confidencePercent: confidencePercent,
                tint: (confidencePercent ?? 0) >= 90 ? .green : .neutral
            )
        case .reviewNeeded:
            return FrameStripTrackingBadge(
                state: .reviewNeeded,
                confidencePercent: confidencePercent,
                tint: .orange
            )
        case .unresolved:
            return FrameStripTrackingBadge(state: .unresolved, tint: .red)
        case .needsExtraction:
            return FrameStripTrackingBadge(state: .needsExtraction, tint: .gray)
        }
    }

    private static func defaultFrameLabel(for orderIndex: Int) -> String {
        "#\(String(format: "%03d", max(orderIndex + 1, 1)))"
    }
}
