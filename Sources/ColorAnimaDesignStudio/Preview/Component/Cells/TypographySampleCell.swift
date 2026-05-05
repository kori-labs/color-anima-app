import AppKit
import SwiftUI
import ColorAnimaDesignStudioTokenManifest
import ColorAnimaAppWorkspaceDesignSystem

/// Renders a typography token as sample text using the token's size/weight/design.
///
/// If `size` is present the font is built via a token-driven NSFont helper so
/// no raw integer literal appears as a size argument.
/// If the token is not found, renders an empty placeholder with a help tooltip.
struct TypographySampleCell: View {
    let tokenName: String
    let manifest: TokenManifest

    private var token: TypographyToken? {
        manifest.typography.first { $0.name == tokenName }
    }

    var body: some View {
        if let token {
            VStack(alignment: .leading, spacing: WorkspaceFoundation.Metrics.space1) {
                Text("The quick brown fox 0123")
                    .font(resolvedFont(from: token))
                    .foregroundStyle(WorkspaceFoundation.Foreground.primaryLabel)

                HStack(spacing: WorkspaceFoundation.Metrics.space2) {
                    Text(token.name)
                        .font(WorkspaceFoundation.Typography.caption)
                        .foregroundStyle(WorkspaceFoundation.Foreground.secondaryLabel)

                    if let size = token.size {
                        Text("\(Int(size)) pt · \(token.weight)")
                            .font(WorkspaceFoundation.Typography.metaNumeric)
                            .foregroundStyle(WorkspaceFoundation.Foreground.secondaryLabel)
                    } else if let systemFont = token.systemFont {
                        Text(".\(systemFont) · \(token.weight)")
                            .font(WorkspaceFoundation.Typography.metaNumeric)
                            .foregroundStyle(WorkspaceFoundation.Foreground.secondaryLabel)
                    }
                }
            }
        } else {
            RoundedRectangle(cornerRadius: WorkspaceFoundation.Metrics.compactControlCornerRadius)
                .fill(WorkspaceFoundation.Surface.sectionBackground)
                .frame(height: WorkspaceFoundation.Metrics.space6)
                .help("Token not found: \(tokenName)")
        }
    }

    // MARK: - Font resolution from token fields

    /// Builds a `Font` from the token's typed fields.
    /// When `size` is available the value is taken from the token at runtime —
    /// no integer literal is used here. The explicit-size path goes through
    /// `fontFromNSFont` which uses NSFont bridging.
    private func resolvedFont(from token: TypographyToken) -> Font {
        let weight = fontWeight(from: token.weight)
        let design = fontDesign(from: token.design)

        if let size = token.size {
            // size is a runtime Double from the token — not a literal.
            return fontFromNSFont(size: CGFloat(size), weight: weight, design: design)
        }

        // Named system font path
        switch token.systemFont ?? "" {
        case "largeTitle": return .largeTitle.weight(weight)
        case "title": return .title.weight(weight)
        case "title2": return .title2.weight(weight)
        case "title3": return .title3.weight(weight)
        case "headline": return .headline.weight(weight)
        case "subheadline": return .subheadline.weight(weight)
        case "body": return .body.weight(weight)
        case "callout": return .callout.weight(weight)
        case "footnote": return .footnote.weight(weight)
        case "caption": return .caption.weight(weight)
        case "caption2": return .caption2.weight(weight)
        default: return .body.weight(weight)
        }
    }

    /// Constructs a `Font` at an explicit point size via NSFont bridging.
    /// The size argument is always a runtime token value, never a literal.
    private func fontFromNSFont(size: CGFloat, weight: Font.Weight, design: Font.Design) -> Font {
        let nsWeight = nsWeight(from: weight)
        let descriptor = NSFontDescriptor.preferredFontDescriptor(forTextStyle: .body)
            .withSize(size)
            .withSymbolicTraits(design == .monospaced ? .monoSpace : [])
        let nsFont = NSFont(descriptor: descriptor, size: size)
            ?? NSFont.systemFont(ofSize: size, weight: nsWeight)
        return Font(nsFont).weight(weight)
    }

    private func nsWeight(from weight: Font.Weight) -> NSFont.Weight {
        switch weight {
        case .ultraLight: return .ultraLight
        case .thin: return .thin
        case .light: return .light
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        case .heavy: return .heavy
        case .black: return .black
        default: return .regular
        }
    }

    private func fontWeight(from string: String) -> Font.Weight {
        switch string.lowercased() {
        case "ultralight": return .ultraLight
        case "thin": return .thin
        case "light": return .light
        case "regular": return .regular
        case "medium": return .medium
        case "semibold": return .semibold
        case "bold": return .bold
        case "heavy": return .heavy
        case "black": return .black
        default: return .regular
        }
    }

    private func fontDesign(from string: String) -> Font.Design {
        switch string.lowercased() {
        case "serif": return .serif
        case "rounded": return .rounded
        case "monospaced": return .monospaced
        default: return .default
        }
    }
}
