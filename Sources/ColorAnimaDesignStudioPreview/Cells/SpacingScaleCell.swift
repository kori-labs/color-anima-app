import SwiftUI
import ColorAnimaDesignStudioTokenManifest
import ColorAnimaAppWorkspaceDesignSystem

/// Renders a spacing token as a bordered box whose width equals the token value.
/// If the token is not found, renders an empty placeholder with a help tooltip.
struct SpacingScaleCell: View {
    let tokenName: String
    let manifest: TokenManifest

    private var token: SpacingToken? {
        manifest.spacing.first { $0.name == tokenName }
    }

    var body: some View {
        if let token {
            HStack(alignment: .center, spacing: WorkspaceFoundation.Metrics.space3) {
                // The box width directly equals the token value so the visual
                // immediately reflects live editor changes.
                RoundedRectangle(cornerRadius: WorkspaceFoundation.Metrics.compactControlCornerRadius)
                    .fill(WorkspaceFoundation.Surface.cardFill)
                    .frame(width: CGFloat(token.value), height: WorkspaceFoundation.Metrics.space6)
                    .overlay(
                        RoundedRectangle(cornerRadius: WorkspaceFoundation.Metrics.compactControlCornerRadius)
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
                .frame(width: WorkspaceFoundation.Metrics.space6, height: WorkspaceFoundation.Metrics.space6)
                .help("Token not found: \(tokenName)")
        }
    }
}
