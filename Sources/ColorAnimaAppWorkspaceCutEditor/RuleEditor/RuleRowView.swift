import ColorAnimaAppWorkspaceApplication
import ColorAnimaAppWorkspaceDesignSystem
import SwiftUI

package struct RuleRowView: View {
    let rule: ColorRule
    let onUpdate: (ColorRule) -> Void
    let onRemove: () -> Void
    let onWhatIfHover: (RGBAColor) -> Void
    let onWhatIfClear: () -> Void

    @State private var isSwatchHovered = false

    package init(
        rule: ColorRule,
        onUpdate: @escaping (ColorRule) -> Void,
        onRemove: @escaping () -> Void,
        onWhatIfHover: @escaping (RGBAColor) -> Void,
        onWhatIfClear: @escaping () -> Void
    ) {
        self.rule = rule
        self.onUpdate = onUpdate
        self.onRemove = onRemove
        self.onWhatIfHover = onWhatIfHover
        self.onWhatIfClear = onWhatIfClear
    }

    package var body: some View {
        HStack(spacing: WorkspaceFoundation.Metrics.space2_5) {
            Toggle("", isOn: enabledBinding)
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()

            Text(RuleConditionSummary.text(for: rule.condition))
                .font(.subheadline)
                .foregroundStyle(rule.isEnabled ? .primary : .secondary)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer()

            Text("then Apply")
                .font(.caption)
                .foregroundStyle(.secondary)

            RoundedRectangle(cornerRadius: WorkspaceFoundation.Metrics.microRadius)
                .fill(rule.color.swiftUIColor)
                .frame(width: 20, height: 20)
                .overlay(
                    RoundedRectangle(cornerRadius: WorkspaceFoundation.Metrics.microRadius)
                        .strokeBorder(.separator, lineWidth: 1)
                )
                .scaleEffect(isSwatchHovered ? 1.15 : 1.0)
                .animation(.easeInOut(duration: 0.1), value: isSwatchHovered)
                .onHover { hovering in
                    isSwatchHovered = hovering
                    if hovering {
                        onWhatIfHover(rule.color)
                    } else {
                        onWhatIfClear()
                    }
                }

            Button {
                onRemove()
            } label: {
                Image(systemName: "trash")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, WorkspaceFoundation.Metrics.space1)
    }

    private var enabledBinding: Binding<Bool> {
        Binding(
            get: { rule.isEnabled },
            set: { newValue in
                var updated = rule
                updated.isEnabled = newValue
                onUpdate(updated)
            }
        )
    }
}

package enum RuleConditionSummary {
    package static func text(for condition: ColorRuleCondition) -> String {
        switch condition {
        case .any:
            return "Any"
        case .backgroundCandidate:
            return "Background"
        case .regionID(let id):
            return "Region: \(id.uuidString.prefix(8))"
        case .regionLabel(let prefix):
            return "Label: \(prefix)"
        }
    }
}
