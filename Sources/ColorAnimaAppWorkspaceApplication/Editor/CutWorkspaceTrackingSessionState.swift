import Foundation

public enum TrackingRunStatus: Hashable, Equatable, Sendable {
    case idle
    case launching
    case running(message: String, current: Int?, total: Int?)
    case cancelling
    case cancelled(framesProcessed: Int, framesTotal: Int)
    case completed
    case failed(message: String)

    public var progressMessage: String? {
        switch self {
        case .launching:
            return "Launching..."
        case let .running(message, current, total):
            guard let current, let total, total > 0 else { return message }
            return "\(message) (\(current)/\(total))"
        case .cancelling:
            return "Cancelling..."
        case let .cancelled(framesProcessed, framesTotal):
            return "\(framesProcessed)/\(framesTotal) frames processed"
        case let .failed(message):
            return message
        case .idle, .completed:
            return nil
        }
    }
}

public struct TrackingQueueCursor: Hashable, Equatable, Sendable {
    public var currentIndex: Int
    public var totalCount: Int

    public init(currentIndex: Int, totalCount: Int) {
        self.currentIndex = max(0, currentIndex)
        self.totalCount = max(0, totalCount)
    }
}

public struct TrackingRunResult: Hashable, Equatable, Sendable {
    public var updatedFrameIDs: [UUID]
    public var unresolvedFrameIDs: [UUID]
    public var promotedAnchorFrameIDs: [UUID]
    public var reviewItemCount: Int

    public init(
        updatedFrameIDs: [UUID] = [],
        unresolvedFrameIDs: [UUID] = [],
        promotedAnchorFrameIDs: [UUID] = [],
        reviewItemCount: Int = 0
    ) {
        self.updatedFrameIDs = updatedFrameIDs
        self.unresolvedFrameIDs = unresolvedFrameIDs
        self.promotedAnchorFrameIDs = promotedAnchorFrameIDs
        self.reviewItemCount = max(0, reviewItemCount)
    }
}

public typealias TrackingSessionState = CutWorkspaceTrackingSessionState

public struct CutWorkspaceTrackingSessionState: Hashable, Equatable, Sendable {
    public var runStatus: TrackingRunStatus
    public var lastRunResult: TrackingRunResult?
    public var queueState: CutWorkspaceTrackingQueueState?
    public var promotedAnchorFrameIDs: [UUID]
    public var excludedAnchorFrameIDs: [UUID]

    public init(
        runStatus: TrackingRunStatus = .idle,
        lastRunResult: TrackingRunResult? = nil,
        queueState: CutWorkspaceTrackingQueueState? = nil,
        promotedAnchorFrameIDs: [UUID] = [],
        excludedAnchorFrameIDs: [UUID] = []
    ) {
        self.runStatus = runStatus
        self.lastRunResult = lastRunResult
        self.queueState = queueState
        self.promotedAnchorFrameIDs = Self.normalizeIDs(promotedAnchorFrameIDs)
        self.excludedAnchorFrameIDs = Self.normalizeIDs(excludedAnchorFrameIDs)
    }

    public mutating func cancelRunIfActive() {
        switch runStatus {
        case .running:
            runStatus = .cancelling
        case .launching:
            runStatus = .idle
        default:
            break
        }
    }

    public var isRunning: Bool {
        switch runStatus {
        case .launching, .running, .cancelling:
            return true
        case .idle, .cancelled, .completed, .failed:
            return false
        }
    }

    public var hasRunOnce: Bool {
        lastRunResult != nil
    }

    public var progressMessage: String? {
        runStatus.progressMessage
    }

    public var regionQueueItems: [CutWorkspaceTrackingQueueItemState] {
        queueState?.queueItems ?? []
    }

    public var queueCursor: TrackingQueueCursor? {
        guard let queueState, queueState.queueItems.isEmpty == false else { return nil }
        return TrackingQueueCursor(
            currentIndex: queueState.clampedQueueIndex,
            totalCount: queueState.queueItems.count
        )
    }

    public var clampedQueueIndex: Int {
        queueState?.clampedQueueIndex ?? 0
    }

    public var currentQueueItem: CutWorkspaceTrackingQueueItemState? {
        queueState?.currentQueueItem
    }

    public func updatingQueueCursor(_ queueIndex: Int) -> CutWorkspaceTrackingSessionState {
        var updated = self
        if var queueState = updated.queueState {
            queueState.queueIndex = max(0, queueIndex)
            updated.queueState = queueState
        }
        return updated
    }

    public func removingQueueItem(
        frameID: UUID,
        regionID: UUID
    ) -> CutWorkspaceTrackingSessionState {
        guard var queueState else { return self }

        queueState.queueItems.removeAll { item in
            item.frameID == frameID && item.regionID == regionID
        }
        queueState.queueIndex = min(
            queueState.queueIndex,
            max(0, queueState.queueItems.count - 1)
        )

        var updated = self
        updated.queueState = queueState
        return updated
    }

    private static func normalizeIDs(_ values: [UUID]) -> [UUID] {
        var seen = Set<UUID>()
        return values
            .sorted { $0.uuidString < $1.uuidString }
            .filter { seen.insert($0).inserted }
    }
}
