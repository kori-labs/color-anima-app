import SwiftUI

package struct ChromeButtonStyle: ButtonStyle {
    package var isDestructive = false
    package var minHeight: CGFloat?
    package var horizontalPadding: CGFloat = 10
    package var verticalPadding: CGFloat = 8
    package var cornerRadius: CGFloat = 10
    package var expandToMaxWidth = false
    package var font: Font?
    package var idleForegroundStyle: Color?
    package var hoverForegroundStyle: Color?

    package init(
        isDestructive: Bool = false,
        minHeight: CGFloat? = nil,
        horizontalPadding: CGFloat = 10,
        verticalPadding: CGFloat = 8,
        cornerRadius: CGFloat = 10,
        expandToMaxWidth: Bool = false,
        font: Font? = nil,
        idleForegroundStyle: Color? = nil,
        hoverForegroundStyle: Color? = nil
    ) {
        self.isDestructive = isDestructive
        self.minHeight = minHeight
        self.horizontalPadding = horizontalPadding
        self.verticalPadding = verticalPadding
        self.cornerRadius = cornerRadius
        self.expandToMaxWidth = expandToMaxWidth
        self.font = font
        self.idleForegroundStyle = idleForegroundStyle
        self.hoverForegroundStyle = hoverForegroundStyle
    }

    package func makeBody(configuration: Configuration) -> some View {
        ChromeButton(configuration: configuration, style: self)
    }
}

private struct ChromeCardModifier: ViewModifier {
    let fill: Color
    let stroke: Color
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(fill)
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(stroke, lineWidth: 1)
            }
            .clipShape(.rect(cornerRadius: cornerRadius))
    }
}

private struct ChromeInteractiveRowModifier: ViewModifier {
    let isActive: Bool
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content.chromeCard(
            fill: isActive ? WorkspaceFoundation.Interaction.interactiveHoverFill : .clear,
            stroke: isActive ? WorkspaceFoundation.Stroke.interactiveHoverStroke : .clear,
            cornerRadius: cornerRadius
        )
    }
}

private struct ChromeSelectablePanelCardModifier: ViewModifier {
    let isActive: Bool
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content.chromeCard(
            fill: isActive
                ? WorkspaceChromeStyle.SelectablePanelCard.activeFill
                : WorkspaceChromeStyle.SelectablePanelCard.idleFill,
            stroke: isActive
                ? WorkspaceChromeStyle.SelectablePanelCard.activeStroke
                : WorkspaceChromeStyle.SelectablePanelCard.idleStroke,
            cornerRadius: cornerRadius
        )
    }
}

package extension View {
    func chromeCard(fill: Color, stroke: Color, cornerRadius: CGFloat) -> some View {
        modifier(
            ChromeCardModifier(
                fill: fill,
                stroke: stroke,
                cornerRadius: cornerRadius
            )
        )
    }

    func chromeInteractiveRow(isActive: Bool, cornerRadius: CGFloat) -> some View {
        modifier(
            ChromeInteractiveRowModifier(
                isActive: isActive,
                cornerRadius: cornerRadius
            )
        )
    }

    func chromeSelectablePanelCard(isActive: Bool, cornerRadius: CGFloat) -> some View {
        modifier(
            ChromeSelectablePanelCardModifier(
                isActive: isActive,
                cornerRadius: cornerRadius
            )
        )
    }
}

private struct ChromeButton: View {
    let configuration: ChromeButtonStyle.Configuration
    let style: ChromeButtonStyle

    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    var body: some View {
        configuration.label
            .font(style.font)
            .foregroundStyle(foregroundStyle)
            .padding(.horizontal, style.horizontalPadding)
            .padding(.vertical, style.verticalPadding)
            .frame(
                maxWidth: style.expandToMaxWidth ? .infinity : nil,
                minHeight: style.minHeight
            )
            .background(backgroundStyle)
            .overlay {
                RoundedRectangle(cornerRadius: style.cornerRadius)
                    .strokeBorder(borderStyle, lineWidth: 1)
            }
            .clipShape(.rect(cornerRadius: style.cornerRadius))
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.12), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }

    private var backgroundStyle: Color {
        guard isEnabled else { return .clear }
        if style.isDestructive && isHovered {
            return WorkspaceFoundation.Interaction.destructiveHoverFill
        }
        if configuration.isPressed {
            return WorkspaceFoundation.Interaction.interactivePressedFill
        }
        if isHovered {
            return WorkspaceFoundation.Interaction.interactiveHoverFill
        }
        return .clear
    }

    private var borderStyle: Color {
        guard isEnabled else { return .clear }
        if style.isDestructive && isHovered {
            return WorkspaceFoundation.Stroke.destructiveHoverStroke
        }
        if configuration.isPressed || isHovered {
            return WorkspaceFoundation.Stroke.interactiveHoverStroke
        }
        return .clear
    }

    private var foregroundStyle: Color {
        guard isEnabled else { return WorkspaceFoundation.Foreground.disabledForeground }
        if style.isDestructive && isHovered {
            return WorkspaceFoundation.Foreground.destructiveForeground
        }
        if configuration.isPressed || isHovered, let hoverForegroundStyle = style.hoverForegroundStyle {
            return hoverForegroundStyle
        }
        if let idleForegroundStyle = style.idleForegroundStyle {
            return idleForegroundStyle
        }
        return WorkspaceFoundation.Foreground.primaryLabel
    }
}
