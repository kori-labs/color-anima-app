import ColorAnimaAppWorkspaceApplication
import ColorAnimaAppWorkspaceDesignSystem
import SwiftUI

package struct RuleEditorView: View {
    let ruleSet: ColorRuleSet
    let onAdd: () -> Void
    let onRemove: (UUID) -> Void
    let onMove: (IndexSet, Int) -> Void
    let onUpdate: (ColorRule) -> Void
    let onWhatIfHover: (UUID, RGBAColor) -> Void
    let onWhatIfClear: () -> Void

    package init(
        ruleSet: ColorRuleSet,
        onAdd: @escaping () -> Void,
        onRemove: @escaping (UUID) -> Void,
        onMove: @escaping (IndexSet, Int) -> Void,
        onUpdate: @escaping (ColorRule) -> Void,
        onWhatIfHover: @escaping (UUID, RGBAColor) -> Void,
        onWhatIfClear: @escaping () -> Void
    ) {
        self.ruleSet = ruleSet
        self.onAdd = onAdd
        self.onRemove = onRemove
        self.onMove = onMove
        self.onUpdate = onUpdate
        self.onWhatIfHover = onWhatIfHover
        self.onWhatIfClear = onWhatIfClear
    }

    package var body: some View {
        VStack(alignment: .leading, spacing: WorkspaceFoundation.Metrics.space2) {
            List {
                ForEach(ruleSet.rules) { rule in
                    RuleRowView(
                        rule: rule,
                        onUpdate: onUpdate,
                        onRemove: { onRemove(rule.id) },
                        onWhatIfHover: { color in onWhatIfHover(rule.id, color) },
                        onWhatIfClear: onWhatIfClear
                    )
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 2, leading: 0, bottom: 2, trailing: 0))
                }
                .onMove { source, destination in
                    onMove(source, destination)
                }
            }
            .listStyle(.plain)
            .frame(minHeight: CGFloat(max(1, ruleSet.rules.count)) * 44)

            Button("Add Rule") {
                onAdd()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }
}
