import SwiftUI
import ColorAnimaDesignStudioTokenManifest
import ColorAnimaAppWorkspaceDesignSystem

/// Lists every `CornerRadiusToken` with a numeric stepper.
struct CornerRadiusTokenEditor: View {
    @Binding var tokens: [CornerRadiusToken]
    let onUpdate: (Int, CornerRadiusToken) -> Void

    var body: some View {
        List {
            ForEach(Array(tokens.enumerated()), id: \.element.name) { index, token in
                CornerRadiusTokenRow(token: token) { updated in
                    onUpdate(index, updated)
                }
                Divider()
                    .foregroundStyle(WorkspaceFoundation.Stroke.divider)
            }
        }
        .listStyle(.inset)
    }
}

// MARK: - Row

private struct CornerRadiusTokenRow: View {
    let token: CornerRadiusToken
    let onUpdate: (CornerRadiusToken) -> Void

    @State private var value: Double

    init(token: CornerRadiusToken, onUpdate: @escaping (CornerRadiusToken) -> Void) {
        self.token = token
        self.onUpdate = onUpdate
        _value = State(initialValue: token.value)
    }

    var body: some View {
        HStack(spacing: WorkspaceFoundation.Metrics.space3) {
            VStack(alignment: .leading, spacing: WorkspaceFoundation.Metrics.microSpace0_5) {
                Text(token.name)
                    .font(WorkspaceFoundation.Typography.primaryLabel)
                    .foregroundStyle(WorkspaceFoundation.Foreground.primaryLabel)
                Text(token.surface)
                    .font(WorkspaceFoundation.Typography.caption)
                    .foregroundStyle(WorkspaceFoundation.Foreground.secondaryLabel)
            }
            Spacer()
            HStack(spacing: WorkspaceFoundation.Metrics.space2) {
                TextField("", value: $value, format: .number)
                    .frame(width: 60)
                    .textFieldStyle(.roundedBorder)
                    .font(WorkspaceFoundation.Typography.metaNumeric)
                    .onChange(of: value) { _, newValue in
                        onUpdate(CornerRadiusToken(name: token.name, surface: token.surface, value: newValue))
                    }
                Stepper("", value: $value, in: 0...50, step: 1)
                    .labelsHidden()
                    .onChange(of: value) { _, newValue in
                        onUpdate(CornerRadiusToken(name: token.name, surface: token.surface, value: newValue))
                    }
                Text("pt")
                    .font(WorkspaceFoundation.Typography.caption)
                    .foregroundStyle(WorkspaceFoundation.Foreground.secondaryLabel)
            }
        }
        .padding(.vertical, WorkspaceFoundation.Metrics.microSpace0_75)
    }
}
