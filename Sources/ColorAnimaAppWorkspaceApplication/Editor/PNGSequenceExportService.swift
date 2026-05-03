// PNGSequenceExportService.swift
// Layer: ColorAnimaAppWorkspaceApplication — orchestration on top of the AppEngine client.
//
// This service replaces the deleted source-only CutWorkspacePNGSequenceExportService
// using public DTOs throughout. It does NOT import ColorAnimaKernel,
// ColorAnimaKernelBridge, or any source-only kernel module. All encoding flows
// via the AppEngine client injected at call time.
//
// The service is intentionally UI-free and MainActor-free: it operates on pure
// value types and delegates encoding to the injected callback.
//
//
// ExportOrchestrator.exportPNGSequence accepts an `encodeFrame` callback:
//
//   encodeFrame: (_ snapshot: ExportFrameSnapshot, _ directoryURL: URL) async throws -> Void
//
// PNGSequenceExportService.makeEncodeFrameCallback(client:namingPolicy:) returns
// a closure with exactly that signature, ready to be injected:
//
//   let callback = PNGSequenceExportService.makeEncodeFrameCallback(
//       client: PNGSequenceEncoderClient()
//   )
//   await ExportOrchestrator.exportPNGSequence(
//       snapshots: snapshots,
//       resolveExportDirectory: { ... },
//       encodeFrame: callback
//   )

import ColorAnimaAppEngine
import CoreGraphics
import Foundation

// MARK: - DTOs

/// Outcome of a full PNG-sequence export via PNGSequenceExportService.
public struct PNGSequenceExportReport: Equatable, Sendable {
    /// Directory URL where the sequence was written.
    public let directoryURL: URL
    /// Ordered URLs of the written PNG files.
    public let writtenURLs: [URL]
    /// Number of frames written.
    public let frameCount: Int
    /// Whether the kernel encoder was used (false when ImageIO fallback was active).
    public let kernelExecuted: Bool

    public init(directoryURL: URL, writtenURLs: [URL], frameCount: Int, kernelExecuted: Bool) {
        self.directoryURL = directoryURL
        self.writtenURLs = writtenURLs
        self.frameCount = frameCount
        self.kernelExecuted = kernelExecuted
    }
}

/// Error types surfaced by the export service.
public enum PNGSequenceExportError: Error, Equatable, Sendable {
    /// The target directory is not writable or does not exist.
    case directoryNotWritable(URL)
    /// An individual frame could not be encoded or written.
    case frameEncodeFailed(frameID: UUID, underlying: String)
}

// MARK: - Naming policy

/// Controls how output filenames are derived from frame order indices.
public enum PNGSequenceNamingPolicy: Equatable, Sendable {
    /// `frame-XXXX.png` (4-digit, 1-based display order index).
    case fourDigitOneBasedIndex
}

// MARK: - Service

/// Orchestrates per-frame PNG encoding for a sequence export.
///
/// All logic is expressed in terms of public DTOs. The service does not hold
/// or mutate workspace state. Encoding is delegated to the injected AppEngine
/// client.
///
/// ## Usage
///
/// Call `makeEncodeFrameCallback(client:namingPolicy:)` to obtain a closure
/// compatible with `ExportOrchestrator.exportPNGSequence`'s `encodeFrame`
/// parameter, then pass it directly to the orchestrator.
public enum PNGSequenceExportService {

    // MARK: - Direct export

    /// Encodes and writes every frame in `snapshots` to `directoryURL`.
    ///
    /// Snapshots are sorted by `orderIndex` (ascending) before encoding so
    /// filenames are deterministic regardless of caller order.
    ///
    /// - Parameters:
    ///   - snapshots: Per-frame composite snapshots. Callers own image resolution and ordering.
    ///   - directoryURL: Destination directory. Must exist and be writable.
    ///   - client: AppEngine encoder client. Injected for testability.
    ///   - namingPolicy: Controls output filename format (default: `.fourDigitOneBasedIndex`).
    /// - Returns: A report summarising the export.
    /// - Throws: `PNGSequenceExportError` on directory or encode failure.
    public static func export(
        snapshots: [ExportFrameSnapshot],
        to directoryURL: URL,
        client: PNGSequenceEncoderClient,
        namingPolicy: PNGSequenceNamingPolicy = .fourDigitOneBasedIndex
    ) throws -> PNGSequenceExportReport {
        try ensureDirectoryWritable(directoryURL)

        let ordered = snapshots.sorted { $0.orderIndex < $1.orderIndex }
        var writtenURLs: [URL] = []
        var kernelExecuted = false
        writtenURLs.reserveCapacity(ordered.count)

        for snapshot in ordered {
            let filename = outputFilename(
                for: snapshot.orderIndex,
                policy: namingPolicy
            )
            let fileURL = directoryURL.appendingPathComponent(filename)

            do {
                let report = try client.encodeFrame(image: snapshot.compositeImage, to: fileURL)
                writtenURLs.append(report.fileURL)
                if report.kernelExecuted { kernelExecuted = true }
            } catch {
                throw PNGSequenceExportError.frameEncodeFailed(
                    frameID: snapshot.frameID,
                    underlying: error.localizedDescription
                )
            }
        }

        return PNGSequenceExportReport(
            directoryURL: directoryURL,
            writtenURLs: writtenURLs,
            frameCount: writtenURLs.count,
            kernelExecuted: kernelExecuted
        )
    }

    // MARK: - Callback factory

    /// Returns a closure compatible with `ExportOrchestrator.exportPNGSequence`'s
    /// `encodeFrame` parameter.
    ///
    /// The returned callback encodes each `ExportFrameSnapshot` to a PNG file
    /// inside `directoryURL` using the provided client. Filenames follow
    /// `namingPolicy`.
    ///
    /// - Parameters:
    ///   - client: AppEngine encoder client. Injected for testability.
    ///   - namingPolicy: Controls output filename format (default: `.fourDigitOneBasedIndex`).
    /// - Returns: A closure `(ExportFrameSnapshot, URL) async throws -> Void`.
    public static func makeEncodeFrameCallback(
        client: PNGSequenceEncoderClient,
        namingPolicy: PNGSequenceNamingPolicy = .fourDigitOneBasedIndex
    ) -> @Sendable (ExportFrameSnapshot, URL) async throws -> Void {
        return { snapshot, directoryURL in
            let filename = outputFilename(for: snapshot.orderIndex, policy: namingPolicy)
            let fileURL = directoryURL.appendingPathComponent(filename)
            _ = try client.encodeFrame(image: snapshot.compositeImage, to: fileURL)
        }
    }

    // MARK: - Private helpers

    private static func outputFilename(
        for orderIndex: Int,
        policy: PNGSequenceNamingPolicy
    ) -> String {
        switch policy {
        case .fourDigitOneBasedIndex:
            return String(format: "frame-%04d.png", orderIndex + 1)
        }
    }

    private static func ensureDirectoryWritable(_ directoryURL: URL) throws {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        let exists = fileManager.fileExists(atPath: directoryURL.path, isDirectory: &isDirectory)
        guard exists, isDirectory.boolValue else {
            throw PNGSequenceExportError.directoryNotWritable(directoryURL)
        }
        guard fileManager.isWritableFile(atPath: directoryURL.path) else {
            throw PNGSequenceExportError.directoryNotWritable(directoryURL)
        }
    }
}
