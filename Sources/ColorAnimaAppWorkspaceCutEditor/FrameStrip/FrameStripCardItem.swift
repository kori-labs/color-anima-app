import Foundation

package enum FrameStripTrackingBadgeState: String, Equatable, Sendable {
    case reference
    case tracked
    case reviewNeeded
    case unresolved
    case needsExtraction
}

package enum FrameStripTrackingBadgeTint: String, Equatable, Sendable {
    case green
    case neutral
    case orange
    case red
    case gray
}

package struct FrameStripTrackingBadge: Equatable, Sendable {
    let state: FrameStripTrackingBadgeState
    let confidencePercent: Int?
    let label: String
    let tint: FrameStripTrackingBadgeTint

    package init(
        state: FrameStripTrackingBadgeState,
        confidencePercent: Int? = nil,
        label: String? = nil,
        tint: FrameStripTrackingBadgeTint
    ) {
        self.state = state
        self.confidencePercent = confidencePercent.map { max(0, min(100, $0)) }
        self.label = label ?? Self.makeLabel(state: state, confidencePercent: self.confidencePercent)
        self.tint = tint
    }

    private static func makeLabel(
        state: FrameStripTrackingBadgeState,
        confidencePercent: Int?
    ) -> String {
        switch state {
        case .reference:
            return "Ref"
        case .tracked:
            return confidencePercent.map { "\($0)%" } ?? "Tracked"
        case .reviewNeeded:
            return confidencePercent.map { "\($0)% ⚠" } ?? "⚠"
        case .unresolved:
            return "— ?"
        case .needsExtraction:
            return "Extract"
        }
    }
}

package struct FrameStripCardItem: Equatable, Sendable {
    let id: UUID
    let frameLabel: String
    let displayFilename: String
    let isDisplayFilenamePlaceholder: Bool
    let isCurrent: Bool
    let isSelected: Bool
    let isIncludedReference: Bool
    let isActiveReference: Bool
    let showsPersistentReferenceAction: Bool
    let trackingBadge: FrameStripTrackingBadge?

    package init(
        id: UUID,
        frameLabel: String,
        displayFilename: String,
        isDisplayFilenamePlaceholder: Bool,
        isCurrent: Bool,
        isSelected: Bool,
        isIncludedReference: Bool,
        isActiveReference: Bool,
        showsPersistentReferenceAction: Bool = false,
        trackingBadge: FrameStripTrackingBadge? = nil
    ) {
        self.id = id
        self.frameLabel = frameLabel
        self.displayFilename = displayFilename
        self.isDisplayFilenamePlaceholder = isDisplayFilenamePlaceholder
        self.isCurrent = isCurrent
        self.isSelected = isSelected
        self.isIncludedReference = isIncludedReference
        self.isActiveReference = isActiveReference
        self.showsPersistentReferenceAction = showsPersistentReferenceAction
        self.trackingBadge = trackingBadge
    }
}
