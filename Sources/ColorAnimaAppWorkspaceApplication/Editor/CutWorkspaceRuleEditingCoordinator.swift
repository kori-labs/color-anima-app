import Foundation

public struct CutWorkspaceRuleEditingState: Hashable, Equatable, Sendable {
    public var colorRuleSet: ColorRuleSet
    public var activeWhatIfPreviewState: RuleWhatIfPreviewState?

    public init(
        colorRuleSet: ColorRuleSet = .empty,
        activeWhatIfPreviewState: RuleWhatIfPreviewState? = nil
    ) {
        self.colorRuleSet = colorRuleSet
        self.activeWhatIfPreviewState = activeWhatIfPreviewState
    }
}

public enum CutWorkspaceRuleEditingCoordinator {
    public static func addRule(
        _ rule: ColorRule,
        in state: inout CutWorkspaceRuleEditingState
    ) {
        state.colorRuleSet.rules.append(rule)
    }

    @discardableResult
    public static func removeRule(
        id: UUID,
        in state: inout CutWorkspaceRuleEditingState
    ) -> Bool {
        let originalCount = state.colorRuleSet.rules.count
        state.colorRuleSet.rules.removeAll { $0.id == id }
        return state.colorRuleSet.rules.count != originalCount
    }

    @discardableResult
    public static func moveRule(
        fromOffsets source: IndexSet,
        toOffset destination: Int,
        in state: inout CutWorkspaceRuleEditingState
    ) -> Bool {
        let validSource = IndexSet(source.filter { state.colorRuleSet.rules.indices.contains($0) })
        guard validSource.isEmpty == false else { return false }

        var rules = state.colorRuleSet.rules
        let movingRules = validSource.sorted().map { rules[$0] }
        for index in validSource.sorted().reversed() {
            rules.remove(at: index)
        }

        let adjustedDestination = destination - validSource.filter { $0 < destination }.count
        let clampedDestination = min(max(0, adjustedDestination), rules.count)
        rules.insert(contentsOf: movingRules, at: clampedDestination)
        state.colorRuleSet.rules = rules

        return true
    }

    @discardableResult
    public static func updateRule(
        _ rule: ColorRule,
        in state: inout CutWorkspaceRuleEditingState
    ) -> Bool {
        guard let index = state.colorRuleSet.rules.firstIndex(where: { $0.id == rule.id }) else {
            return false
        }
        state.colorRuleSet.rules[index] = rule
        return true
    }

    public static func triggerWhatIfPreview(
        ruleID: UUID,
        simulatedColor: RGBAColor,
        in state: inout CutWorkspaceRuleEditingState
    ) {
        state.activeWhatIfPreviewState = RuleWhatIfPreviewState(
            baselineRuleSet: state.colorRuleSet,
            simulatedRuleID: ruleID,
            simulatedColor: simulatedColor
        )
    }

    public static func clearWhatIfPreview(
        in state: inout CutWorkspaceRuleEditingState
    ) {
        state.activeWhatIfPreviewState = nil
    }
}
