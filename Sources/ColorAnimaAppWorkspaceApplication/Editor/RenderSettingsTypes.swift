public enum RenderOutputFormat: String, Codable, Hashable, Sendable, CaseIterable {
    case png
}

public struct RenderSettingsModel: Codable, Hashable, Sendable {
    public var outputFormat: RenderOutputFormat
    public var quality: Double
    public var resolutionScale: Double

    public init(
        outputFormat: RenderOutputFormat = .png,
        quality: Double = 1.0,
        resolutionScale: Double = 1.0
    ) {
        self.outputFormat = outputFormat
        self.quality = quality
        self.resolutionScale = resolutionScale
    }

    public static let `default` = RenderSettingsModel()
}
