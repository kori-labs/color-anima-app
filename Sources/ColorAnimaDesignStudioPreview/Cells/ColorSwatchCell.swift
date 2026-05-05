import SwiftUI
import ColorAnimaDesignStudioTokenManifest
import ColorAnimaAppWorkspaceDesignSystem

/// Renders a color swatch for a named `ColorToken` from the live manifest.
/// Shows the resolved color as a filled rounded rectangle with the token name below.
/// If the token is not found, renders an empty placeholder with a help tooltip.
struct ColorSwatchCell: View {
    let tokenName: String
    let manifest: TokenManifest

    private var token: ColorToken? {
        manifest.colors.first { $0.name == tokenName }
    }

    var body: some View {
        if let token {
            HStack(spacing: WorkspaceFoundation.Metrics.space3) {
                resolvedColor(for: token.value)
                    .frame(
                        width: WorkspaceFoundation.Metrics.space6 * 2,
                        height: WorkspaceFoundation.Metrics.space6
                    )
                    .clipShape(RoundedRectangle(cornerRadius: WorkspaceFoundation.Metrics.compactControlCornerRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: WorkspaceFoundation.Metrics.compactControlCornerRadius)
                            .stroke(WorkspaceFoundation.Stroke.divider, lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: WorkspaceFoundation.Metrics.microSpace0_5) {
                    Text(token.name)
                        .font(WorkspaceFoundation.Typography.secondaryLabel)
                        .foregroundStyle(WorkspaceFoundation.Foreground.primaryLabel)
                    Text(valueDescription(for: token.value))
                        .font(WorkspaceFoundation.Typography.caption)
                        .foregroundStyle(WorkspaceFoundation.Foreground.secondaryLabel)
                }
            }
        } else {
            missingTokenPlaceholder
        }
    }

    // MARK: - Color resolution

    private func resolvedColor(for value: ColorValue) -> Color {
        switch value {
        case let .rgba(r, g, b, a):
            return Color(red: r, green: g, blue: b, opacity: a)
        case let .systemColor(name):
            return systemColor(named: name)
        case let .opacityOf(base, alpha):
            return systemColor(named: base).opacity(alpha)
        case let .dynamic(light, _):
            // For preview purposes, use the light variant.
            return Color(red: light.r, green: light.g, blue: light.b, opacity: light.a)
        }
    }

    private func systemColor(named name: String) -> Color {
        switch name {
        case "secondary": return Color.secondary
        case "accentColor": return Color.accentColor
        case "primary": return Color.primary
        default: return Color.secondary
        }
    }

    private func valueDescription(for value: ColorValue) -> String {
        switch value {
        case let .rgba(r, g, b, a):
            return String(format: "R %.2f  G %.2f  B %.2f  A %.2f", r, g, b, a)
        case let .systemColor(name):
            return "system(\(name))"
        case let .opacityOf(base, alpha):
            return "\(base) @ \(Int(alpha * 100))%"
        case .dynamic:
            return "dynamic (light/dark)"
        }
    }

    // MARK: - Missing token fallback

    private var missingTokenPlaceholder: some View {
        RoundedRectangle(cornerRadius: WorkspaceFoundation.Metrics.compactControlCornerRadius)
            .fill(WorkspaceFoundation.Surface.sectionBackground)
            .frame(
                width: WorkspaceFoundation.Metrics.space6 * 2,
                height: WorkspaceFoundation.Metrics.space6
            )
            .help("Token not found: \(tokenName)")
    }
}
