import Foundation

// MARK: - Top-level manifest envelope

/// Versioned container for all design-system tokens extracted from the
/// ColorAnimaAppWorkspaceDesignSystem source files.
///
/// Schema version 1 layout:
///   { "schemaVersion": 1, "extractedAt": "<ISO8601>",
///     "colors": [...], "spacing": [...], "typography": [...], "cornerRadii": [...] }
public struct TokenManifest: Codable, Sendable, Equatable {
    public let schemaVersion: Int
    public let extractedAt: String
    public let colors: [ColorToken]
    public let spacing: [SpacingToken]
    public let typography: [TypographyToken]
    public let cornerRadii: [CornerRadiusToken]

    public init(
        schemaVersion: Int = 1,
        extractedAt: String,
        colors: [ColorToken],
        spacing: [SpacingToken],
        typography: [TypographyToken],
        cornerRadii: [CornerRadiusToken]
    ) {
        self.schemaVersion = schemaVersion
        self.extractedAt = extractedAt
        self.colors = colors
        self.spacing = spacing
        self.typography = typography
        self.cornerRadii = cornerRadii
    }
}

// MARK: - Color token

public struct ColorToken: Codable, Sendable, Equatable {
    /// Fully-qualified Swift name, e.g. "WorkspaceFoundation.Surface.canvas"
    public let name: String
    /// Source file owner, e.g. "WorkspaceFoundation"
    public let surface: String
    public let value: ColorValue

    public init(name: String, surface: String, value: ColorValue) {
        self.name = name
        self.surface = surface
        self.value = value
    }
}

public enum ColorValue: Codable, Sendable, Equatable {
    /// Explicit RGBA components (0.0–1.0 each).
    case rgba(r: Double, g: Double, b: Double, a: Double)
    /// Reference to a named system color (e.g. "secondary", "accentColor").
    case systemColor(String)
    /// Opacity variant of a named system or semantic color.
    case opacityOf(base: String, alpha: Double)
    /// Dynamic light/dark pair — both legs stored as RGBA.
    case dynamic(light: RGBAValue, dark: RGBAValue)

    // MARK: Codable

    private enum CodingKeys: String, CodingKey {
        case type, r, g, b, a, base, alpha, light, dark
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(String.self, forKey: .type)
        switch type {
        case "rgba":
            self = .rgba(
                r: try c.decode(Double.self, forKey: .r),
                g: try c.decode(Double.self, forKey: .g),
                b: try c.decode(Double.self, forKey: .b),
                a: try c.decode(Double.self, forKey: .a)
            )
        case "systemColor":
            self = .systemColor(try c.decode(String.self, forKey: .base))
        case "opacityOf":
            self = .opacityOf(
                base: try c.decode(String.self, forKey: .base),
                alpha: try c.decode(Double.self, forKey: .alpha)
            )
        case "dynamic":
            self = .dynamic(
                light: try c.decode(RGBAValue.self, forKey: .light),
                dark: try c.decode(RGBAValue.self, forKey: .dark)
            )
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: c, debugDescription: "Unknown ColorValue type: \(type)")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .rgba(r, g, b, a):
            try c.encode("rgba", forKey: .type)
            try c.encode(r, forKey: .r)
            try c.encode(g, forKey: .g)
            try c.encode(b, forKey: .b)
            try c.encode(a, forKey: .a)
        case let .systemColor(name):
            try c.encode("systemColor", forKey: .type)
            try c.encode(name, forKey: .base)
        case let .opacityOf(base, alpha):
            try c.encode("opacityOf", forKey: .type)
            try c.encode(base, forKey: .base)
            try c.encode(alpha, forKey: .alpha)
        case let .dynamic(light, dark):
            try c.encode("dynamic", forKey: .type)
            try c.encode(light, forKey: .light)
            try c.encode(dark, forKey: .dark)
        }
    }
}

/// Flat RGBA tuple used inside ColorValue.dynamic.
public struct RGBAValue: Codable, Sendable, Equatable {
    public let r: Double
    public let g: Double
    public let b: Double
    public let a: Double

    public init(r: Double, g: Double, b: Double, a: Double) {
        self.r = r
        self.g = g
        self.b = b
        self.a = a
    }
}

// MARK: - Spacing token

public struct SpacingToken: Codable, Sendable, Equatable {
    public let name: String
    public let surface: String
    public let value: Double

    public init(name: String, surface: String, value: Double) {
        self.name = name
        self.surface = surface
        self.value = value
    }
}

// MARK: - Typography token

public struct TypographyToken: Codable, Sendable, Equatable {
    public let name: String
    public let surface: String
    /// Pixel size for explicit-size fonts; nil for named system fonts like .body, .caption.
    public let size: Double?
    public let weight: String
    public let design: String
    /// Named system font if applicable (e.g. "body", "callout", "caption").
    public let systemFont: String?

    public init(
        name: String,
        surface: String,
        size: Double?,
        weight: String,
        design: String,
        systemFont: String?
    ) {
        self.name = name
        self.surface = surface
        self.size = size
        self.weight = weight
        self.design = design
        self.systemFont = systemFont
    }
}

// MARK: - Corner radius token

public struct CornerRadiusToken: Codable, Sendable, Equatable {
    public let name: String
    public let surface: String
    public let value: Double

    public init(name: String, surface: String, value: Double) {
        self.name = name
        self.surface = surface
        self.value = value
    }
}
