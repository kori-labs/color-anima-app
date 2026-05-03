import CoreGraphics
import Foundation

/// Result of splitting a single composite image into outline/highlight/shadow layers.
public struct UnifiedLayerSplitResult: Sendable {
    public let outlineArtwork: ImportedArtwork
    public let highlightArtwork: ImportedArtwork?
    public let shadowArtwork: ImportedArtwork?

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

/// Outcome of a unified-layer import attempt.
public enum UnifiedLayerImportOutcome: Equatable, Sendable {
    case imported(outlineFrameID: UUID)
    case cancelled
    case failed(message: String)
}

/// Result for one URL in a parallel batch import.
public enum UnifiedLayerBatchResult: @unchecked Sendable {
    case success(index: Int, url: URL, splitResult: UnifiedLayerSplitResult)
    case failure(index: Int, url: URL, error: Error)
}

/// Callback-driven orchestrator for the unified-layer import workflow.
///
/// Replaces `UnifiedLayerImportCoordinator` on the public app side.
/// This orchestrator never imports any banned source-only or kernel-internal
/// type (no raster bitmap value type, no workspace cut model, no facade app
/// model, no detected-region value type, no kernel-impl symbol).
///
/// ## Raster-decode injection point
///
/// supplies the actual raster-decode implementation. The callback receives a
/// file URL and returns `ImportedFrameBytes`. The orchestrator converts the
/// bytes to a `CGImage` via `ImageBytesDecoder` (public, Foundation-only)
/// so that the rest of the split/apply flow can remain kernel-free.
///
/// If no `decodeFrame` callback is supplied the orchestrator expects the
/// caller to provide pre-decoded `ImportedArtwork` directly via the
/// `splitArtwork` callback instead.
@MainActor
public enum UnifiedLayerImportOrchestrator {

    // MARK: - Single-file import

    /// Presents a file prompt, loads and splits the chosen file, then applies
    /// the split result to the workspace via the supplied asset callbacks.
    ///
    /// - Parameters:
    ///   - promptForFile: Async callback that presents a file picker and returns the chosen URL, or `nil` to cancel.
    ///   - splitArtwork: Async callback that performs the actual layer split given decoded bytes. Returns a `UnifiedLayerSplitResult`.
    ///   - outlineRef: Optional existing asset ref for the outline slot.
    ///   - highlightRef: Optional existing asset ref for the highlight slot.
    ///   - shadowRef: Optional existing asset ref for the shadow slot.
    ///   - applyToWorkspace: Async callback that writes the split result into workspace state and returns the target frame ID.
    @discardableResult
    public static func importUnifiedLayer(
        promptForFile: () async -> URL?,
        decodeFrame: (URL) async throws -> ImportedFrameBytes,
        splitArtwork: (ImportedFrameBytes) async throws -> UnifiedLayerSplitResult,
        outlineRef: CutAssetRef?,
        highlightRef: CutAssetRef?,
        shadowRef: CutAssetRef?,
        applyToWorkspace: (
            _ result: UnifiedLayerSplitResult,
            _ outlineRef: CutAssetRef?,
            _ highlightRef: CutAssetRef?,
            _ shadowRef: CutAssetRef?
        ) async throws -> UUID
    ) async -> UnifiedLayerImportOutcome {
        guard let url = await promptForFile() else {
            return .cancelled
        }

        do {
            let frameBytes = try await decodeFrame(url)
            let splitResult = try await splitArtwork(frameBytes)
            let frameID = try await applyToWorkspace(splitResult, outlineRef, highlightRef, shadowRef)
            return .imported(outlineFrameID: frameID)
        } catch {
            return .failed(message: error.localizedDescription)
        }
    }

    // MARK: - Parallel batch import

    /// Loads and splits many URLs concurrently. Emits each result to
    /// `onResult` as soon as that URL finishes (streaming), then returns
    /// the full ordered batch.
    ///
    /// - Parameters:
    ///   - urls: Ordered list of composite-image URLs to import.
    ///   - maxConcurrent: Optional cap on in-flight decode+split tasks.
    ///   - decodeFrame: Async callback that decodes a URL to `ImportedFrameBytes`.
    ///   - splitArtwork: Async callback that performs the layer split given decoded bytes.
    ///   - onResult: Called once per URL in completion order (not input order). Use for progress UI.
    /// - Returns: Ordered-by-input-index array of results.
    public static func loadAndSplitParallel(
        urls: [URL],
        maxConcurrent: Int? = nil,
        decodeFrame: @Sendable @escaping (URL) async throws -> ImportedFrameBytes,
        splitArtwork: @Sendable @escaping (ImportedFrameBytes) async throws -> UnifiedLayerSplitResult,
        onResult: (@Sendable (UnifiedLayerBatchResult) -> Void)? = nil
    ) async -> [UnifiedLayerBatchResult] {
        guard urls.isEmpty == false else { return [] }
        let cap = max(1, maxConcurrent ?? 4)

        return await withTaskGroup(of: UnifiedLayerBatchResult.self) { group in
            var results: [UnifiedLayerBatchResult?] = Array(repeating: nil, count: urls.count)
            var nextIndex = 0
            var inFlight = 0

            func spawn(index: Int) {
                let url = urls[index]
                group.addTask {
                    do {
                        let frameBytes = try await decodeFrame(url)
                        let splitResult = try await splitArtwork(frameBytes)
                        return .success(index: index, url: url, splitResult: splitResult)
                    } catch {
                        return .failure(index: index, url: url, error: error)
                    }
                }
            }

            while nextIndex < urls.count, inFlight < cap {
                spawn(index: nextIndex)
                nextIndex += 1
                inFlight += 1
            }

            while let result = await group.next() {
                inFlight -= 1
                let index: Int
                switch result {
                case let .success(i, _, _): index = i
                case let .failure(i, _, _): index = i
                }
                results[index] = result
                onResult?(result)

                if nextIndex < urls.count {
                    spawn(index: nextIndex)
                    nextIndex += 1
                    inFlight += 1
                }
            }

            return results.compactMap { $0 }
        }
    }
}
