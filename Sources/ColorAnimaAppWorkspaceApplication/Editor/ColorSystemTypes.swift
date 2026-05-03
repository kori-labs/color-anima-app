import Foundation

public struct RGBAColor: Codable, Hashable, Equatable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1.0) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    public static let clear = RGBAColor(red: 0, green: 0, blue: 0, alpha: 0)
    public static let white = RGBAColor(red: 1, green: 1, blue: 1, alpha: 1)
    public static let black = RGBAColor(red: 0, green: 0, blue: 0, alpha: 1)

    public func withAlpha(_ value: Double) -> RGBAColor {
        RGBAColor(red: red, green: green, blue: blue, alpha: value)
    }
}

public struct ColorRoles: Codable, Hashable, Equatable, Sendable {
    public var base: RGBAColor
    public var highlight: RGBAColor
    public var shadow: RGBAColor

    public init(base: RGBAColor, highlight: RGBAColor, shadow: RGBAColor) {
        self.base = base
        self.highlight = highlight
        self.shadow = shadow
    }

    public static let neutral = ColorRoles(
        base: .white,
        highlight: RGBAColor(red: 0.95, green: 0.95, blue: 0.95),
        shadow: RGBAColor(red: 0.6, green: 0.6, blue: 0.6)
    )
}

public struct StatusPalette: Identifiable, Codable, Hashable, Equatable, Sendable {
    public var id: String { name }
    public var name: String
    public var roles: ColorRoles

    public init(name: String, roles: ColorRoles) {
        self.name = name
        self.roles = roles
    }
}

public struct ColorSystemSubset: Identifiable, Codable, Hashable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var isHighlightEnabled: Bool
    public var isShadowEnabled: Bool
    public var palettes: [StatusPalette]

    public init(
        id: UUID = UUID(),
        name: String,
        isHighlightEnabled: Bool = true,
        isShadowEnabled: Bool = true,
        palettes: [StatusPalette]
    ) {
        self.id = id
        self.name = name
        self.isHighlightEnabled = isHighlightEnabled
        self.isShadowEnabled = isShadowEnabled
        self.palettes = palettes
    }
}

public struct ColorSystemGroup: Identifiable, Codable, Hashable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var subsets: [ColorSystemSubset]

    public init(
        id: UUID = UUID(),
        name: String,
        subsets: [ColorSystemSubset]
    ) {
        self.id = id
        self.name = name
        self.subsets = subsets
    }
}
