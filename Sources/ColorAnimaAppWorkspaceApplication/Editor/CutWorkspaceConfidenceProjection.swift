import Foundation

public struct FrameConfidenceProjectionInput: Hashable, Sendable, Identifiable {
    public var id: UUID { frameID }
    public var frameID: UUID
    public var frameLabel: String?
    public var orderIndex: Int
    public var regions: [RegionConfidenceProjectionInput]

    public init(
        frameID: UUID,
        frameLabel: String? = nil,
        orderIndex: Int,
        regions: [RegionConfidenceProjectionInput]
    ) {
        self.frameID = frameID
        self.frameLabel = frameLabel
        self.orderIndex = orderIndex
        self.regions = regions
    }
}

public struct RegionConfidenceProjectionInput: Hashable, Sendable, Identifiable {
    public var id: UUID { regionID }
    public var regionID: UUID
    public var regionDisplayName: String
    public var confidenceValue: Double?
    public var reviewState: ConfidenceReviewState
    public var reasonCodes: [TrackingReviewReasonCode]

    public init(
        regionID: UUID,
        regionDisplayName: String = "Region",
        confidenceValue: Double? = nil,
        reviewState: ConfidenceReviewState,
        reasonCodes: [TrackingReviewReasonCode] = []
    ) {
        self.regionID = regionID
        self.regionDisplayName = regionDisplayName.isEmpty ? "Region" : regionDisplayName
        self.confidenceValue = confidenceValue
        self.reviewState = reviewState
        self.reasonCodes = reasonCodes
    }
}

public enum CutWorkspaceConfidenceProjection {
    public static func frameRows(
        from frames: [FrameConfidenceProjectionInput]
    ) -> [FrameConfidenceRow] {
        frames.compactMap(frameRow(for:))
    }

    public static func filteredFrameRows(
        from frames: [FrameConfidenceProjectionInput],
        filter: ConfidenceReviewFilter
    ) -> [FrameConfidenceRow] {
        let rows = frameRows(from: frames)
        switch filter {
        case .all:
            return rows
        case .reviewNeeded:
            return rows.filter { $0.reviewState == .reviewNeeded }
        case .unresolved:
            return rows.filter { $0.reviewState == .unresolved }
        }
    }

    private static func frameRow(
        for frame: FrameConfidenceProjectionInput
    ) -> FrameConfidenceRow? {
        guard frame.regions.isEmpty == false else { return nil }

        let regionRows = frame.regions
            .sorted { $0.regionID.uuidString < $1.regionID.uuidString }
            .map { region in
                RegionConfidenceRow(
                    regionID: region.regionID,
                    regionDisplayName: region.regionDisplayName,
                    confidenceValue: region.confidenceValue ?? 0,
                    reviewState: region.reviewState,
                    reasonCodes: region.reasonCodes
                )
            }

        return FrameConfidenceRow(
            frameID: frame.frameID,
            frameLabel: frame.frameLabel ?? defaultFrameLabel(for: frame.orderIndex),
            orderIndex: frame.orderIndex,
            reviewState: worstReviewState(in: frame.regions),
            averageConfidence: averageConfidence(in: frame.regions),
            regionResults: regionRows
        )
    }

    private static func defaultFrameLabel(for orderIndex: Int) -> String {
        "#\(String(format: "%03d", max(orderIndex + 1, 1)))"
    }

    private static func worstReviewState(
        in regions: [RegionConfidenceProjectionInput]
    ) -> ConfidenceReviewState {
        if regions.contains(where: { $0.reviewState == .unresolved }) {
            return .unresolved
        }
        if regions.contains(where: { $0.reviewState == .reviewNeeded }) {
            return .reviewNeeded
        }
        return .tracked
    }

    private static func averageConfidence(
        in regions: [RegionConfidenceProjectionInput]
    ) -> Double {
        guard regions.isEmpty == false else { return 0 }
        let total = regions.reduce(0.0) { $0 + ($1.confidenceValue ?? 0) }
        return total / Double(regions.count)
    }
}
