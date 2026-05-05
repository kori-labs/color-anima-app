import SwiftUI
import ColorAnimaDesignStudioTokenManifest
import ColorAnimaAppWorkspaceDesignSystem

/// Lists every `TypographyToken` with size stepper + weight/design pickers.
struct TypographyTokenEditor: View {
    @Binding var tokens: [TypographyToken]
    let onUpdate: (Int, TypographyToken) -> Void

    var body: some View {
        List {
            ForEach(Array(tokens.enumerated()), id: \.element.name) { index, token in
                TypographyTokenRow(token: token) { updated in
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

private struct TypographyTokenRow: View {
    let token: TypographyToken
    let onUpdate: (TypographyToken) -> Void

    private static let weightOptions = ["regular", "medium", "semibold", "bold"]
    private static let designOptions = ["default", "monospaced", "rounded"]

    @State private var size: Double
    @State private var weight: String
    @State private var design: String

    init(token: TypographyToken, onUpdate: @escaping (TypographyToken) -> Void) {
        self.token = token
        self.onUpdate = onUpdate
        _size = State(initialValue: token.size ?? 13)
        _weight = State(initialValue: token.weight)
        _design = State(initialValue: token.design)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: WorkspaceFoundation.Metrics.space2) {
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
            }

            if let systemFont = token.systemFont {
                Text("Named system font: \(systemFont)")
                    .font(WorkspaceFoundation.Typography.caption)
                    .foregroundStyle(WorkspaceFoundation.Foreground.secondaryLabel)
            }

            HStack(spacing: WorkspaceFoundation.Metrics.space3) {
                if token.size != nil {
                    HStack(spacing: WorkspaceFoundation.Metrics.space2) {
                        Text("Size")
                            .font(WorkspaceFoundation.Typography.caption)
                            .foregroundStyle(WorkspaceFoundation.Foreground.secondaryLabel)
                        TextField("", value: $size, format: .number)
                            .frame(width: 52)
                            .textFieldStyle(.roundedBorder)
                            .font(WorkspaceFoundation.Typography.metaNumeric)
                            .onChange(of: size) { _, _ in emitUpdate() }
                        Stepper("", value: $size, in: 6...72, step: 1)
                            .labelsHidden()
                            .onChange(of: size) { _, _ in emitUpdate() }
                        Text("pt")
                            .font(WorkspaceFoundation.Typography.caption)
                            .foregroundStyle(WorkspaceFoundation.Foreground.secondaryLabel)
                    }
                }

                Picker("Weight", selection: $weight) {
                    ForEach(Self.weightOptions, id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .font(WorkspaceFoundation.Typography.caption)
                .onChange(of: weight) { _, _ in emitUpdate() }

                Picker("Design", selection: $design) {
                    ForEach(Self.designOptions, id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .font(WorkspaceFoundation.Typography.caption)
                .onChange(of: design) { _, _ in emitUpdate() }
            }
        }
        .padding(.vertical, WorkspaceFoundation.Metrics.microSpace0_75)
    }

    private func emitUpdate() {
        let updated = TypographyToken(
            name: token.name,
            surface: token.surface,
            size: token.size != nil ? size : nil,
            weight: weight,
            design: design,
            systemFont: token.systemFont
        )
        onUpdate(updated)
    }
}
