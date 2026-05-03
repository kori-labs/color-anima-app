// PNGSequenceEncoderBridge.swift
// Layer: ColorAnimaKernelBridge — Bridge entrypoints only. No app-side logic.
//
// Kernel C surface investigation result:
//   (only ca_pipeline_version() is currently exposed).
//   PNG encoding is therefore implemented via ImageIO framework at the
//   AppEngine layer (PNGSequenceEncoderClient.swift), which does not require
//   a kernel C function.
//
//   This Bridge file provides:
//     1. The public EncoderInputFrame DTO — raw bytes wrapper that crosses
//        the boundary without exposing any banned raster type.
//     2. A stub PNGSequenceEncoderBridge that returns .unavailable,
//        forward-compatible for future kernel-side PNG encoding exposure.
//
//   kernel xcframework header, replace the stub body in encode(frame:) with
//   the real FFI call.  The DTO shapes below are forward-compatible.
//
//   1. Public DTOs only — names scoped to Bridge target (Encoder* prefix).
//   2. Result returns — every call returns Result<DTO, KernelBridgeError>.
//   3. No-binary fallback — compiles and runs when #if !canImport(ColorAnimaKernel).
//   4. Symbol-scan clean — no banned terms from the red-team deny-list.
//   5. 3-layer split — Bridge owns FFI; AppEngine owns public client; workspace owns orchestration.

#if canImport(ColorAnimaKernel)
import ColorAnimaKernel
#endif

import Foundation

// MARK: - Bridge DTOs

/// Raw frame bytes input for PNG encoding.
///
/// This is the public DTO that crosses the FFI boundary. It carries raw RGBA
/// pixel data without referencing any banned source-only raster type.
public struct EncoderInputFrame: Equatable, Sendable {
    /// Pixel width of the frame.
    public let width: Int
    /// Pixel height of the frame.
    public let height: Int
    /// Number of bytes per row (stride). May include padding.
    public let bytesPerRow: Int
    /// Raw RGBA pixel bytes. Length must equal `bytesPerRow * height`.
    public let bytes: Data

    public init(width: Int, height: Int, bytesPerRow: Int, bytes: Data) {
        self.width = width
        self.height = height
        self.bytesPerRow = bytesPerRow
        self.bytes = bytes
    }
}

/// Result of a single-frame kernel-side PNG encode.
public struct EncoderFrameResult: Equatable, Sendable {
    /// Encoded PNG bytes for the frame.
    public let pngData: Data

    public init(pngData: Data) {
        self.pngData = pngData
    }
}

// MARK: - Bridge

/// FFI bridge stub for kernel-side PNG frame encoding.
///
/// This is the ONLY type in the app repo that would be permitted to call a
/// this struct.
///
/// by the kernel xcframework.  PNG encoding is handled at the AppEngine layer
/// via ImageIO.  This stub returns .unavailable so the AppEngine can detect
/// kernel availability and fall back to ImageIO gracefully.
public struct PNGSequenceEncoderBridge: Sendable {

    public init() {}

    /// Encodes a single frame to PNG bytes via the kernel C ABI.
    ///
    /// Returns `.failure(.unavailable)` when the kernel binary is not linked
    /// or when no C-ABI PNG encode function has been exposed yet.
    ///
    /// - Note: Kernel C surface investigation (2026-05-03): only
    ///   ca_pipeline_version() is currently exposed.  This method returns
    ///   kernel xcframework header.  Follow-up required in core repo.
    public func encode(frame: EncoderInputFrame) -> Result<EncoderFrameResult, KernelBridgeError> {
        #if canImport(ColorAnimaKernel)
        // Return .unavailable so the AppEngine layer falls back to ImageIO.
        // Replace this stub with the real FFI call once the core repo exposes it.
        return .failure(.unavailable)
        #else
        return .failure(.unavailable)
        #endif
    }

    /// Returns whether the kernel binary is linked and exposes the PNG encode
    /// C function. Currently always false (stub; see encode(frame:)).
    public var isPNGEncodingAvailable: Bool {
        #if canImport(ColorAnimaKernel)
        return false
        #else
        return false
        #endif
    }
}
