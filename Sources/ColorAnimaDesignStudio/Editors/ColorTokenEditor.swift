import SwiftUI
import AppKit
import ColorAnimaDesignStudioTokenManifest
import ColorAnimaAppWorkspaceDesignSystem

/// Lists every `ColorToken` with an inline editor.
/// - `.rgba` tokens: backed by `NSColorWell` so exact RGB values are picked.
/// - `.systemColor` and `.opacityOf` tokens: shown as read-only labels.
/// - `.dynamic` tokens: shows light/dark swatches, both editable.
struct ColorTokenEditor: View {
    @Binding var tokens: [ColorToken]
    let onUpdate: (Int, ColorToken) -> Void

    var body: some View {
        List {
            ForEach(Array(tokens.enumerated()), id: \.element.name) { index, token in
                ColorTokenRow(
                    token: token,
                    onUpdate: { updated in onUpdate(index, updated) }
                )
                Divider()
                    .foregroundStyle(WorkspaceFoundation.Stroke.divider)
            }
        }
        .listStyle(.inset)
    }
}

// MARK: - Row

private struct ColorTokenRow: View {
    let token: ColorToken
    let onUpdate: (ColorToken) -> Void

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
            colorControl(for: token)
        }
        .padding(.vertical, WorkspaceFoundation.Metrics.microSpace0_75)
    }

    @ViewBuilder
    private func colorControl(for token: ColorToken) -> some View {
        switch token.value {
        case let .rgba(r, g, b, a):
            RGBAColorWell(r: r, g: g, b: b, a: a) { newR, newG, newB, newA in
                let updated = ColorToken(
                    name: token.name,
                    surface: token.surface,
                    value: .rgba(r: newR, g: newG, b: newB, a: newA)
                )
                onUpdate(updated)
            }

        case let .dynamic(light, dark):
            HStack(spacing: WorkspaceFoundation.Metrics.space2) {
                VStack(spacing: WorkspaceFoundation.Metrics.microSpace0_5) {
                    Text("L")
                        .font(WorkspaceFoundation.Typography.caption)
                        .foregroundStyle(WorkspaceFoundation.Foreground.secondaryLabel)
                    RGBAColorWell(r: light.r, g: light.g, b: light.b, a: light.a) { nr, ng, nb, na in
                        let updated = ColorToken(
                            name: token.name,
                            surface: token.surface,
                            value: .dynamic(
                                light: RGBAValue(r: nr, g: ng, b: nb, a: na),
                                dark: dark
                            )
                        )
                        onUpdate(updated)
                    }
                }
                VStack(spacing: WorkspaceFoundation.Metrics.microSpace0_5) {
                    Text("D")
                        .font(WorkspaceFoundation.Typography.caption)
                        .foregroundStyle(WorkspaceFoundation.Foreground.secondaryLabel)
                    RGBAColorWell(r: dark.r, g: dark.g, b: dark.b, a: dark.a) { nr, ng, nb, na in
                        let updated = ColorToken(
                            name: token.name,
                            surface: token.surface,
                            value: .dynamic(
                                light: light,
                                dark: RGBAValue(r: nr, g: ng, b: nb, a: na)
                            )
                        )
                        onUpdate(updated)
                    }
                }
            }

        case let .systemColor(name):
            readOnlyBadge("system: \(name)")

        case let .opacityOf(base, alpha):
            readOnlyBadge("\(base) @ \(String(format: "%.0f%%", alpha * 100))")
        }
    }

    private func readOnlyBadge(_ label: String) -> some View {
        Text(label)
            .font(WorkspaceFoundation.Typography.caption)
            .foregroundStyle(WorkspaceFoundation.Foreground.secondaryLabel)
            .padding(.horizontal, WorkspaceFoundation.Metrics.microSpace1_75)
            .padding(.vertical, WorkspaceFoundation.Metrics.microSpace0_75)
            .background(WorkspaceFoundation.Surface.tagFill)
            .clipShape(RoundedRectangle(cornerRadius: WorkspaceFoundation.Metrics.compactControlCornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: WorkspaceFoundation.Metrics.compactControlCornerRadius)
                    .stroke(WorkspaceFoundation.Stroke.tagBorder, lineWidth: 1)
            )
    }
}

// MARK: - NSColorWell bridge

/// Wraps `NSColorWell` to give a native macOS color picker for RGBA tokens.
private struct RGBAColorWell: NSViewRepresentable {
    let r: Double
    let g: Double
    let b: Double
    let a: Double
    let onChange: (Double, Double, Double, Double) -> Void

    func makeNSView(context: Context) -> NSColorWell {
        let well = NSColorWell(style: .minimal)
        well.color = NSColor(
            calibratedRed: r,
            green: g,
            blue: b,
            alpha: a
        )
        well.target = context.coordinator
        well.action = #selector(Coordinator.colorChanged(_:))
        return well
    }

    func updateNSView(_ nsView: NSColorWell, context: Context) {
        let desired = NSColor(
            calibratedRed: r,
            green: g,
            blue: b,
            alpha: a
        )
        if nsView.color != desired {
            nsView.color = desired
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onChange: onChange)
    }

    final class Coordinator: NSObject {
        let onChange: (Double, Double, Double, Double) -> Void

        init(onChange: @escaping (Double, Double, Double, Double) -> Void) {
            self.onChange = onChange
        }

        @MainActor @objc func colorChanged(_ sender: NSColorWell) {
            let c = sender.color.usingColorSpace(.genericRGB) ?? sender.color
            onChange(c.redComponent, c.greenComponent, c.blueComponent, c.alphaComponent)
        }
    }
}
