import Foundation

public struct RuleWhatIfPreviewState: Hashable, Equatable, Sendable {
    public let baselineRuleSet: ColorRuleSet
    public let simulatedRuleID: UUID
    public let simulatedColor: RGBAColor

    public init(
        baselineRuleSet: ColorRuleSet,
        simulatedRuleID: UUID,
        simulatedColor: RGBAColor
    ) {
        self.baselineRuleSet = baselineRuleSet
        self.simulatedRuleID = simulatedRuleID
        self.simulatedColor = simulatedColor
    }
}
