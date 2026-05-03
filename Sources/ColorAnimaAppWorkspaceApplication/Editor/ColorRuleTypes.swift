import Foundation

public enum ColorRuleCondition: Codable, Hashable, Sendable {
    case regionID(UUID)
    case regionLabel(String)
    case backgroundCandidate
    case any
}

public struct ColorRule: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var condition: ColorRuleCondition
    public var color: RGBAColor
    public var isEnabled: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        condition: ColorRuleCondition,
        color: RGBAColor,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.condition = condition
        self.color = color
        self.isEnabled = isEnabled
    }
}

public struct ColorRuleSet: Codable, Hashable, Sendable {
    public var rules: [ColorRule]

    public init(rules: [ColorRule] = []) {
        self.rules = rules
    }

    public static let empty = ColorRuleSet(rules: [])
}
