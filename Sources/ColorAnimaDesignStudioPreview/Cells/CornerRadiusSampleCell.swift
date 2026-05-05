import SwiftUI
import ColorAnimaDesignStudioTokenManifest
import ColorAnimaAppWorkspaceDesignSystem

/// Renders a corner-radius token as a filled rounded rectangle whose corner radius
/// reflects the live token value. If the token is not found, renders an empty
/// placeholder with a help tooltip.
struct CornerRadiusSampleCell: View {
    let tokenName: String
    let manifest: TokenManifest

    private var token: CornerRadiusToken? {
        manifest.cornerRadii.first { $0.name == tokenName }
    }

    var body: some View {
        if let token {
            HStack(spacing: WorkspaceFoundation.Metrics.space3) {
                // cornerRadius value comes from the token at runtime — not a literal.
                RoundedRectangle(cornerRadius: CGFloat(token.value))
                    .fill(WorkspaceFoundation.Surface.cardFill)
                    .frame(
                        width: WorkspaceFoundation.Metrics.space7 * 2,
                        height: WorkspaceFoundation.Metrics.space7
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: CGFloat(token.value))
                            .stroke(WorkspaceFoundation.Stroke.divider, lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: WorkspaceFoundation.Metrics.microSpace0_5) {
                    Text(token.name)
                        .font(WorkspaceFoundation.Typography.secondaryLabel)
                        .foregroundStyle(WorkspaceFoundation.Foreground.primaryLabel)
                    Text("\(Int(token.value)) pt")
                        .font(WorkspaceFoundation.Typography.metaNumeric)
                        .foregroundStyle(WorkspaceFoundation.Foreground.secondaryLabel)
                }
            }
        } else {
            RoundedRectangle(cornerRadius: WorkspaceFoundation.Metrics.compactControlCornerRadius)
                .fill(WorkspaceFoundation.Surface.sectionBackground)
                .frame(
                    width: WorkspaceFoundation.Metrics.space7 * 2,
                    height: WorkspaceFoundation.Metrics.space7
                )
                .help("Token not found: \(tokenName)")
        }
    }
}
