import CoreGraphics
import Foundation

/// Outcome of a single-frame or sequence export attempt.
public enum ExportOutcome: Equatable, Sendable {
    case exported(url: URL)
    case cancelled
    case failed(message: String)
}

/// Outcome of a PNG-sequence export attempt.
public enum ExportSequenceOutcome: Equatable, Sendable {
    case exported(frameCount: Int, directoryURL: URL)
    case cancelled
    case failed(message: String)
}

/// Input snapshot for a single frame in a PNG-sequence export.
///
/// Callers (e.g. `ProjectSessionModel+ExportActions`) assemble one of these
/// per frame before handing the batch to `ExportOrchestrator.exportPNGSequence`.
/// The orchestrator passes each snapshot to the encoder callback; it does not
public struct ExportFrameSnapshot: Sendable {
    public let frameID: UUID
    public let orderIndex: Int

    /// Composite CGImage for this frame, already composited by the caller.
    public let compositeImage: CGImage

    public init(frameID: UUID, orderIndex: Int, compositeImage: CGImage) {
        self.frameID = frameID
        self.orderIndex = orderIndex
        self.compositeImage = compositeImage
    }
}

/// Callback-driven export orchestrator that owns save-target resolution,
/// prompt flow, and encoder callback wiring.
///
/// This orchestrator replaces `CutWorkspaceExportCoordinator` on the public
/// app side. It never imports any banned source-only or kernel-internal type
/// (no workspace cut model, no facade app model, no raster bitmap value type,
/// no detected-region value type, no kernel-impl symbol).
///
/// ## Encoder callback hook
///
/// (`bridge/png-sequence-export`). When that wave lands it will supply a
/// real implementation that encodes a `CGImage` to PNG bytes via the Bridge.
/// Until then callers can provide a Foundation-based fallback or leave the
/// hook nil to skip encoding.
@MainActor
public enum ExportOrchestrator {

    // MARK: - Single-frame export

    /// Validates that an outline image is available, computes the save target
    /// via `resolveSaveTarget`, then hands the composite image to
    /// `encodeAndWrite` for serialisation.
    ///
    /// - Parameters:
    ///   - definition: Metadata describing the export type (title, filename, annotation flag).
    ///   - outlineArtwork: The cut's outline artwork. `nil` triggers a validation failure.
    ///   - compositeImage: Pre-composited CGImage supplied by the caller.
    ///   - resolveSaveTarget: Async callback that presents a save panel and returns the chosen URL, or `nil` to cancel.
    @discardableResult
    public static func exportFrame(
        definition: WorkspaceExportDefinition,
        outlineArtwork: ImportedArtwork?,
        compositeImage: CGImage?,
        resolveSaveTarget: () async -> URL?,
        encodeAndWrite: (CGImage, URL) async throws -> Void
    ) async -> ExportOutcome {
        guard outlineArtwork != nil else {
            return .failed(message: "Import an outline image before exporting.")
        }
        guard let image = compositeImage else {
            return .failed(message: "Nothing to export yet.")
        }

        guard let url = await resolveSaveTarget() else {
            return .cancelled
        }

        do {
            try await encodeAndWrite(image, url)
            return .exported(url: url)
        } catch {
            return .failed(message: error.localizedDescription)
        }
    }

    // MARK: - PNG sequence export

    /// Exports a pre-assembled batch of frame snapshots to a directory.
    ///
    /// The orchestrator iterates the snapshots in order and invokes
    /// `encodeFrame` for each one. Bytes-level encoding is delegated entirely
    /// to the callback — this coordinator never touches raw pixel data.
    ///
    /// - Parameters:
    ///   - snapshots: Ordered per-frame composite snapshots. Callers own input
    ///     resolution, layer loading, and ordering.
    ///   - resolveExportDirectory: Async callback that presents a directory picker and returns the chosen URL, or `nil` to cancel.
    ///   - encodeFrame: Callback invoked once per frame. Receives the snapshot
    ///     supplies the real implementation.
    @discardableResult
    public static func exportPNGSequence(
        snapshots: [ExportFrameSnapshot],
        resolveExportDirectory: () async -> URL?,
        encodeFrame: (_ snapshot: ExportFrameSnapshot, _ directoryURL: URL) async throws -> Void
    ) async -> ExportSequenceOutcome {
        guard snapshots.isEmpty == false else {
            return .failed(message: "No frames available to export.")
        }

        guard let directoryURL = await resolveExportDirectory() else {
            return .cancelled
        }

        do {
            for snapshot in snapshots {
                try await encodeFrame(snapshot, directoryURL)
            }
            return .exported(frameCount: snapshots.count, directoryURL: directoryURL)
        } catch {
            return .failed(message: error.localizedDescription)
        }
    }
}
