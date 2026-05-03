// PNGSequenceEncoderClient.swift
// Layer: ColorAnimaAppEngine — public app-side client wrapping the Bridge call.
//
// Encoding strategy (2026-05-03):
//   PNG encoding is therefore implemented here via ImageIO framework, which
//   is available on macOS without a kernel dependency.
//
//   When the kernel bridge stub returns .unavailable, this client falls back
//   to ImageIO automatically.  Once the kernel exposes a PNG encode function,
//   isPNGEncodingAvailable will become true and the kernel path will be taken
//   instead.
//
// This layer does NOT import ColorAnimaKernel directly; all kernel access
// goes via PNGSequenceEncoderBridge.

import ColorAnimaKernelBridge
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// MARK: - AppEngine-side DTOs

/// Report returned after encoding a single PNG frame.
public struct PNGEncodeFrameReport: Equatable, Sendable {
    /// URL of the written PNG file.
    public let fileURL: URL
    /// Whether the kernel executed the encode (false when falling back to ImageIO).
    public let kernelExecuted: Bool

    public init(fileURL: URL, kernelExecuted: Bool) {
        self.fileURL = fileURL
        self.kernelExecuted = kernelExecuted
    }
}

/// Report returned after encoding a full PNG sequence.
public struct PNGEncodeSequenceReport: Equatable, Sendable {
    /// Directory URL where the sequence was written.
    public let directoryURL: URL
    /// Number of frames written.
    public let frameCount: Int
    /// Whether the kernel executed the encode for all frames.
    public let kernelExecuted: Bool

    public init(directoryURL: URL, frameCount: Int, kernelExecuted: Bool) {
        self.directoryURL = directoryURL
        self.frameCount = frameCount
        self.kernelExecuted = kernelExecuted
    }
}

/// Error types surfaced by the encoder client.
public enum PNGEncoderClientError: Error, Equatable, Sendable {
    /// ImageIO could not produce PNG data from the provided CGImage.
    case imageIOEncodeFailed
    /// The file could not be written to disk.
    case fileWriteFailed(URL)
    /// The target directory is not writable or does not exist.
    case directoryNotWritable(URL)
}

// MARK: - Client

/// App-side client for PNG frame encoding.
///
/// Wraps PNGSequenceEncoderBridge and falls back to ImageIO when the kernel
/// C function is not yet exposed.  Callers never interact with Bridge types
/// directly.
///
/// ## Encoding path selection
///
/// 1. If `bridge.isPNGEncodingAvailable` is true (future state), the kernel
///    C-ABI path is used and `kernelExecuted` is set to true in reports.
/// 2. Otherwise (current state, 2026-05-03), ImageIO encodes the CGImage to
///    PNG and `kernelExecuted` is false.
///
/// ## Thread safety
///
/// `PNGSequenceEncoderClient` is a value type (struct) and is `Sendable`.
/// CGImage encoding via ImageIO is thread-safe.
public struct PNGSequenceEncoderClient: Sendable {
    private let bridge: PNGSequenceEncoderBridge

    public init(bridge: PNGSequenceEncoderBridge = PNGSequenceEncoderBridge()) {
        self.bridge = bridge
    }

    /// Whether the underlying kernel PNG encode function is available.
    /// Currently always false (stub; see PNGSequenceEncoderBridge.swift).
    public var isKernelEncodingAvailable: Bool {
        bridge.isPNGEncodingAvailable
    }

    /// Encodes a single CGImage to a PNG file at the given URL.
    ///
    /// Falls back to ImageIO when the kernel C function is not exposed.
    ///
    /// - Parameters:
    ///   - image: The CGImage to encode.
    ///   - fileURL: Destination file URL. Written atomically.
    /// - Returns: A report describing the encode outcome.
    /// - Throws: `PNGEncoderClientError` on encode or write failure.
    public func encodeFrame(
        image: CGImage,
        to fileURL: URL
    ) throws -> PNGEncodeFrameReport {
        if bridge.isPNGEncodingAvailable {
            return try encodeViaKernel(image: image, to: fileURL)
        } else {
            return try encodeViaImageIO(image: image, to: fileURL)
        }
    }

    // MARK: - Private helpers

    private func encodeViaKernel(
        image: CGImage,
        to fileURL: URL
    ) throws -> PNGEncodeFrameReport {
        // Build raw bytes from the CGImage for the Bridge DTO.
        let width = image.width
        let height = image.height
        let bytesPerRow = width * 4
        var pixelData = [UInt8](repeating: 0, count: bytesPerRow * height)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw PNGEncoderClientError.imageIOEncodeFailed
        }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        let frame = EncoderInputFrame(
            width: width,
            height: height,
            bytesPerRow: bytesPerRow,
            bytes: Data(pixelData)
        )

        switch bridge.encode(frame: frame) {
        case .success(let result):
            do {
                try result.pngData.write(to: fileURL, options: .atomic)
                return PNGEncodeFrameReport(fileURL: fileURL, kernelExecuted: true)
            } catch {
                throw PNGEncoderClientError.fileWriteFailed(fileURL)
            }
        case .failure:
            // Bridge became unavailable mid-run; fall through to ImageIO.
            return try encodeViaImageIO(image: image, to: fileURL)
        }
    }

    private func encodeViaImageIO(
        image: CGImage,
        to fileURL: URL
    ) throws -> PNGEncodeFrameReport {
        guard let destination = CGImageDestinationCreateWithURL(
            fileURL as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            throw PNGEncoderClientError.imageIOEncodeFailed
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw PNGEncoderClientError.imageIOEncodeFailed
        }
        return PNGEncodeFrameReport(fileURL: fileURL, kernelExecuted: false)
    }
}
