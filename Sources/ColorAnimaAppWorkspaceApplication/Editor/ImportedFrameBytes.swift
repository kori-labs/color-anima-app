import Foundation

/// Raw decoded frame bytes passed across the export/import boundary.
///
/// populate via the encoder/decoder callback injected into `ExportOrchestrator`
/// and `UnifiedLayerImportOrchestrator`. Callers never see the banned
/// source-only raster bitmap value type or any kernel-internal type.
public struct ImportedFrameBytes: Sendable {
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
