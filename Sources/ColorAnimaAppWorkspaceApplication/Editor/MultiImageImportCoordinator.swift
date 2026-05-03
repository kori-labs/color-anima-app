import Foundation

public struct MultiImageImportFramePayload: Sendable {
    public var outlineArtwork: ImportedArtwork
    public var highlightArtwork: ImportedArtwork?
    public var shadowArtwork: ImportedArtwork?

    public init(
        outlineArtwork: ImportedArtwork,
        highlightArtwork: ImportedArtwork? = nil,
        shadowArtwork: ImportedArtwork? = nil
    ) {
        self.outlineArtwork = outlineArtwork
        self.highlightArtwork = highlightArtwork
        self.shadowArtwork = shadowArtwork
    }
}

public struct MultiImageImportCommitRequest: Sendable {
    public var index: Int
    public var frameID: UUID
    public var payload: MultiImageImportFramePayload

    public init(index: Int, frameID: UUID, payload: MultiImageImportFramePayload) {
        self.index = index
        self.frameID = frameID
        self.payload = payload
    }
}

public enum MultiImageImportFrameLoadResult: Sendable {
    case success(index: Int, url: URL, payload: MultiImageImportFramePayload)
    case failure(index: Int, url: URL, message: String)

    public var index: Int {
        switch self {
        case let .success(index, _, _), let .failure(index, _, _):
            index
        }
    }

    public var url: URL {
        switch self {
        case let .success(_, url, _), let .failure(_, url, _):
            url
        }
    }
}

public struct MultiImageImportRunResult: Equatable, Sendable {
    public var decodedCount: Int
    public var failedCount: Int
    public var committedCount: Int
    public var selectedFrameID: UUID?
    public var deletedFrameIDs: [UUID]
    public var wasCancelled: Bool

    public init(
        decodedCount: Int = 0,
        failedCount: Int = 0,
        committedCount: Int = 0,
        selectedFrameID: UUID? = nil,
        deletedFrameIDs: [UUID] = [],
        wasCancelled: Bool = false
    ) {
        self.decodedCount = decodedCount
        self.failedCount = failedCount
        self.committedCount = committedCount
        self.selectedFrameID = selectedFrameID
        self.deletedFrameIDs = deletedFrameIDs
        self.wasCancelled = wasCancelled
    }
}

@MainActor
public enum MultiImageImportCoordinator {
    public static func run(
        urls: [URL],
        targetFrameIDs: [UUID],
        createdFrameIDs: [UUID] = [],
        expectedResolution: ProjectCanvasResolution,
        progress: MultiImageImportProgress,
        feedback: LongRunningActionFeedback,
        results: AsyncStream<MultiImageImportFrameLoadResult>,
        commit: @MainActor (MultiImageImportCommitRequest) throws -> Void,
        selectFrame: @MainActor (UUID) -> Void = { _ in },
        deleteCreatedFrames: @MainActor ([UUID]) -> Void = { _ in },
        syncFromWorkspace: @MainActor () -> Void = {},
        getErrorMessage: @MainActor () -> String? = { nil },
        setErrorMessage: @MainActor (String?) -> Void = { _ in }
    ) async -> MultiImageImportRunResult {
        let state = MultiImageImportStreamingState()
        var decodedCount = 0
        var failedCount = 0
        var committedCount = 0
        var terminatedByCancel = false
        var selectedFrameID: UUID?

        for await result in results {
            if Task.isCancelled || feedbackStateIsCancelled(feedback) {
                terminatedByCancel = true
                break
            }

            switch result {
            case let .success(index, url, payload):
                state.pendingByIndex[index] = payload
                progress.recordDecoded(url: url)
                decodedCount += 1

            case let .failure(index, _, message):
                state.failedIndices.insert(index)
                progress.recordFailed()
                failedCount += 1
                appendFailureMessage(
                    frameIndex: index,
                    message: message,
                    getErrorMessage: getErrorMessage,
                    setErrorMessage: setErrorMessage
                )
            }

            let committed = drainStreamingPrefix(
                state: state,
                targetFrameIDs: targetFrameIDs,
                expectedResolution: expectedResolution,
                progress: progress,
                commit: commit,
                syncFromWorkspace: syncFromWorkspace,
                getErrorMessage: getErrorMessage,
                setErrorMessage: setErrorMessage
            )
            committedCount += committed
        }

        if terminatedByCancel == false {
            committedCount += drainStreamingPrefix(
                state: state,
                targetFrameIDs: targetFrameIDs,
                expectedResolution: expectedResolution,
                progress: progress,
                commit: commit,
                syncFromWorkspace: syncFromWorkspace,
                getErrorMessage: getErrorMessage,
                setErrorMessage: setErrorMessage
            )
        }

        if terminatedByCancel {
            let uncommittedCreated = createdFrameIDs.filter { id in
                guard let index = targetFrameIDs.firstIndex(of: id) else { return false }
                return index > state.committedUpTo
            }
            if uncommittedCreated.isEmpty == false {
                deleteCreatedFrames(uncommittedCreated)
            }
            preserveAggregatedErrorsAcrossSync(
                syncFromWorkspace: syncFromWorkspace,
                getErrorMessage: getErrorMessage,
                setErrorMessage: setErrorMessage
            )
            if feedback.isTerminal == false {
                feedback.markCancelled()
            }
            return MultiImageImportRunResult(
                decodedCount: decodedCount,
                failedCount: failedCount,
                committedCount: committedCount,
                deletedFrameIDs: uncommittedCreated,
                wasCancelled: true
            )
        }

        selectedFrameID = targetFrameIDs.enumerated().first { index, _ in
            state.failedIndices.contains(index) == false
        }?.element
        if let selectedFrameID {
            selectFrame(selectedFrameID)
        }

        preserveAggregatedErrorsAcrossSync(
            syncFromWorkspace: syncFromWorkspace,
            getErrorMessage: getErrorMessage,
            setErrorMessage: setErrorMessage
        )

        if feedback.isTerminal == false {
            if state.failedIndices.isEmpty {
                feedback.markCompleted()
            } else if state.failedIndices.count == urls.count {
                let message = getErrorMessage()
                    ?? "Multi-image Import failed for all \(urls.count) frame(s)."
                feedback.markFailed(message: message)
            } else {
                feedback.markCompleted()
            }
        }

        return MultiImageImportRunResult(
            decodedCount: decodedCount,
            failedCount: state.failedIndices.count,
            committedCount: committedCount,
            selectedFrameID: selectedFrameID,
            wasCancelled: false
        )
    }

    private static func feedbackStateIsCancelled(_ feedback: LongRunningActionFeedback) -> Bool {
        if case .cancelled = feedback.state { return true }
        return false
    }

    @discardableResult
    private static func drainStreamingPrefix(
        state: MultiImageImportStreamingState,
        targetFrameIDs: [UUID],
        expectedResolution: ProjectCanvasResolution,
        progress: MultiImageImportProgress,
        commit: @MainActor (MultiImageImportCommitRequest) throws -> Void,
        syncFromWorkspace: @MainActor () -> Void,
        getErrorMessage: @MainActor () -> String?,
        setErrorMessage: @MainActor (String?) -> Void
    ) -> Int {
        var committed = 0
        while true {
            let nextIndex = state.committedUpTo + 1
            guard nextIndex < targetFrameIDs.count else { break }

            if state.failedIndices.contains(nextIndex) {
                state.committedUpTo = nextIndex
                continue
            }

            guard let payload = state.pendingByIndex.removeValue(forKey: nextIndex) else { break }
            let frameID = targetFrameIDs[nextIndex]

            if let message = CutWorkspaceSequenceImportCoordinator.validateImportedArtworkResolution(
                payload.outlineArtwork,
                expectedResolution: expectedResolution,
                kind: .outline
            ) {
                state.failedIndices.insert(nextIndex)
                progress.recordFailed()
                appendFailureMessage(
                    frameIndex: nextIndex,
                    message: message,
                    getErrorMessage: getErrorMessage,
                    setErrorMessage: setErrorMessage
                )
                state.committedUpTo = nextIndex
                continue
            }

            do {
                try commit(
                    MultiImageImportCommitRequest(
                        index: nextIndex,
                        frameID: frameID,
                        payload: payload
                    )
                )
                state.committedUpTo = nextIndex
                progress.recordCommitted(count: 1)
                committed += 1
            } catch {
                state.failedIndices.insert(nextIndex)
                progress.recordFailed()
                appendFailureMessage(
                    frameIndex: nextIndex,
                    message: error.localizedDescription,
                    getErrorMessage: getErrorMessage,
                    setErrorMessage: setErrorMessage
                )
                state.committedUpTo = nextIndex
            }
        }

        if committed > 0 {
            preserveAggregatedErrorsAcrossSync(
                syncFromWorkspace: syncFromWorkspace,
                getErrorMessage: getErrorMessage,
                setErrorMessage: setErrorMessage
            )
        }
        return committed
    }

    private static func appendFailureMessage(
        frameIndex: Int,
        message: String,
        getErrorMessage: @MainActor () -> String?,
        setErrorMessage: @MainActor (String?) -> Void
    ) {
        let label = "#\(String(format: "%03d", frameIndex + 1))"
        let line = "Frame \(label): \(message)"
        if let existing = getErrorMessage(), existing.isEmpty == false {
            setErrorMessage(existing + "\n" + line)
        } else {
            setErrorMessage(line)
        }
    }

    private static func preserveAggregatedErrorsAcrossSync(
        syncFromWorkspace: @MainActor () -> Void,
        getErrorMessage: @MainActor () -> String?,
        setErrorMessage: @MainActor (String?) -> Void
    ) {
        let aggregatedFailureMessages = getErrorMessage()
        syncFromWorkspace()
        if let aggregatedFailureMessages, aggregatedFailureMessages.isEmpty == false {
            setErrorMessage(aggregatedFailureMessages)
        }
    }
}

@MainActor
private final class MultiImageImportStreamingState {
    var pendingByIndex: [Int: MultiImageImportFramePayload] = [:]
    var committedUpTo: Int = -1
    var failedIndices: Set<Int> = []
}
