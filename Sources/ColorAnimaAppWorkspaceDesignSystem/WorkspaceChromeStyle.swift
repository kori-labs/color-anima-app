import AppKit
import SwiftUI

package enum WorkspaceChromeStyle {
    package enum Sidebar {
        package static var primaryLabel: Color {
            WorkspaceFoundation.Foreground.primaryLabel
        }

        package static var secondaryLabel: Color {
            WorkspaceFoundation.Foreground.secondaryLabel
        }

        package static var divider: Color {
            WorkspaceFoundation.Stroke.divider
        }

        package static var surfaceFill: Color {
            WorkspaceFoundation.Surface.surfaceFill
        }

        package static var panelCardFill: Color {
            WorkspaceChromeAppearance.dynamicColor(
                light: NSColor(calibratedWhite: 1, alpha: 1),
                dark: NSColor(calibratedWhite: 0.12, alpha: 1)
            )
        }

        package static var panelCardStroke: Color {
            Color(nsColor: .separatorColor).opacity(0.18)
        }

        package static var interactiveHoverFill: Color {
            WorkspaceFoundation.Interaction.interactiveHoverFill
        }

        package static var interactivePressedFill: Color {
            WorkspaceFoundation.Interaction.interactivePressedFill
        }

        package static var interactiveHoverStroke: Color {
            WorkspaceFoundation.Stroke.interactiveHoverStroke
        }

        package static var interactiveIdleStroke: Color {
            WorkspaceFoundation.Stroke.interactiveIdleStroke
        }

        package static var concentricCreateOuterRestFill: Color {
            WorkspaceChromeAppearance.dynamicColor(
                light: NSColor.black.withAlphaComponent(0.035),
                dark: NSColor.white.withAlphaComponent(0.045)
            )
        }

        package static var concentricCreateInnerRestFill: Color {
            WorkspaceChromeAppearance.dynamicColor(
                light: NSColor.black.withAlphaComponent(0.085),
                dark: NSColor.white.withAlphaComponent(0.11)
            )
        }

        package static var selectionAccent: Color {
            WorkspaceFoundation.Selection.selectionAccent
        }

        package static var connectorStroke: Color {
            Color(nsColor: .separatorColor).opacity(0.72)
        }

        package static var destructiveHoverFill: Color {
            WorkspaceFoundation.Interaction.destructiveHoverFill
        }

        package static var destructiveHoverStroke: Color {
            WorkspaceFoundation.Stroke.destructiveHoverStroke
        }

        package static var destructiveForeground: Color {
            WorkspaceFoundation.Foreground.destructiveForeground
        }
    }

    package enum Inspector {
        package static var idleCardFill: Color {
            .clear
        }

        package static var idleCardStroke: Color {
            .clear
        }

        package static var selectedCardFill: Color {
            WorkspaceFoundation.Interaction.interactiveHoverFill
        }

        package static var selectedCardStroke: Color {
            WorkspaceFoundation.Stroke.interactiveHoverStroke
        }

        package static var selectedSwatchStroke: Color {
            WorkspaceChromeAppearance.dynamicColor(
                light: NSColor.controlAccentColor.withAlphaComponent(0.52),
                dark: NSColor.controlAccentColor.withAlphaComponent(0.76)
            )
        }

        package static var sectionDivider: Color {
            WorkspaceFoundation.Stroke.divider
        }

        package static var swatchStroke: Color {
            WorkspaceChromeAppearance.dynamicColor(
                light: NSColor.black.withAlphaComponent(0.12),
                dark: NSColor.white.withAlphaComponent(0.22)
            )
        }
    }

    package enum SelectablePanelCard {
        package static var idleFill: Color {
            .clear
        }

        package static var idleStroke: Color {
            .clear
        }

        package static var activeFill: Color {
            WorkspaceFoundation.Interaction.interactiveHoverFill
        }

        package static var activeStroke: Color {
            .clear
        }
    }

    package static var commandBarBackground: Color {
        WorkspaceFoundation.Surface.surfaceFill
    }

    package static var commandBarBorder: Color {
        WorkspaceFoundation.Stroke.divider
    }

    package static var workspacePanelDividerNSColor: NSColor {
        WorkspaceFoundation.Shell.dividerNSColor
    }

    package static var workspacePanelDivider: Color {
        WorkspaceFoundation.Shell.divider
    }

    package static var sidebarButtonHoverFill: Color {
        WorkspaceFoundation.Interaction.interactiveHoverFill
    }

    package static var sidebarButtonPressedFill: Color {
        WorkspaceFoundation.Interaction.interactivePressedFill
    }

    package static var sidebarButtonHoverStroke: Color {
        WorkspaceFoundation.Stroke.interactiveHoverStroke
    }

    package static var sidebarButtonIdleStroke: Color {
        WorkspaceFoundation.Stroke.interactiveIdleStroke
    }

    package static var canvasBackgroundStart: Color {
        WorkspaceChromeAppearance.dynamicColor(
            light: NSColor(calibratedWhite: 0.97, alpha: 1),
            dark: NSColor(calibratedRed: 0.12, green: 0.13, blue: 0.15, alpha: 1)
        )
    }

    package static var canvasBackgroundEnd: Color {
        WorkspaceChromeAppearance.dynamicColor(
            light: NSColor(calibratedWhite: 0.93, alpha: 1),
            dark: NSColor(calibratedRed: 0.08, green: 0.09, blue: 0.11, alpha: 1)
        )
    }

    package static var cardFill: Color {
        WorkspaceChromeAppearance.dynamicColor(
            light: NSColor(calibratedWhite: 1, alpha: 0.88),
            dark: NSColor(calibratedWhite: 0.14, alpha: 1)
        )
    }

    package static var cardStroke: Color {
        WorkspaceChromeAppearance.dynamicColor(
            light: NSColor.black.withAlphaComponent(0.08),
            dark: NSColor.white.withAlphaComponent(0.08)
        )
    }

    package static var badgeFill: Color {
        WorkspaceChromeAppearance.dynamicColor(
            light: NSColor(calibratedWhite: 1, alpha: 0.92),
            dark: NSColor(calibratedWhite: 0.16, alpha: 1)
        )
    }

    package static var viewportFill: Color {
        WorkspaceChromeAppearance.dynamicColor(
            light: { appearance in
                WorkspaceChromeAppearance.resolvedColor(.textBackgroundColor, alpha: 0.75, in: appearance)
            },
            dark: { _ in
                WorkspaceChromeAppearance.darkNeutralBackground
            }
        )
    }

    package static var checkerboardLight: Color {
        WorkspaceChromeAppearance.dynamicColor(
            light: NSColor(calibratedWhite: 0.94, alpha: 1),
            dark: NSColor(calibratedWhite: 0.2, alpha: 1)
        )
    }

    package static var checkerboardDark: Color {
        WorkspaceChromeAppearance.dynamicColor(
            light: NSColor(calibratedWhite: 0.88, alpha: 1),
            dark: NSColor(calibratedWhite: 0.15, alpha: 1)
        )
    }

    package static var overlayPanelFill: Color {
        WorkspaceChromeAppearance.dynamicColor(
            light: NSColor(calibratedWhite: 1, alpha: 1),
            dark: NSColor(calibratedWhite: 0.08, alpha: 1)
        )
    }

    package static var overlayPanelStroke: Color {
        Color(nsColor: .separatorColor).opacity(0.22)
    }

    package static var elevatedShadow: Color {
        WorkspaceChromeAppearance.dynamicColor(
            light: NSColor.black.withAlphaComponent(0.08),
            dark: NSColor.black.withAlphaComponent(0.18)
        )
    }

    package static var pipelineIndex: Color {
        Color.accentColor.opacity(0.9)
    }

    package static var selectionStroke: Color {
        Color.accentColor.opacity(0.92)
    }

    /// Stroke width for the static selection boundary outline.
    /// Thicker than the D&D hover dash (1.5 pt) so selection and hover are
    /// visually distinguishable when both overlays are simultaneously visible.
    package static let selectionStrokeWidth: CGFloat = 2.5

    /// Glow opacity for the selection boundary outline.
    package static let selectionGlowOpacity: Double = 0.28

    package static var chromeTintFill: Color {
        WorkspaceChromeAppearance.dynamicColor(
            light: NSColor(calibratedRed: 0.92, green: 0.96, blue: 0.985, alpha: 1),
            dark: NSColor(calibratedRed: 0.13, green: 0.15, blue: 0.19, alpha: 1)
        )
    }

    package static var sidebarFill: Color {
        WorkspaceFoundation.Surface.surfaceFill
    }

    package static var workspaceShellFill: Color {
        WorkspaceFoundation.Shell.background
    }

    package static var workspaceShellStroke: Color {
        WorkspaceFoundation.Shell.stroke
    }

    package static var workspaceShellShadow: Color {
        WorkspaceFoundation.Shell.shadow
    }

    package static var inspectorCardFill: Color {
        Sidebar.panelCardFill
    }

    package static var inspectorCardStroke: Color {
        Sidebar.panelCardStroke
    }
}
