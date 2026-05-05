import AppKit
import SwiftUI

package enum WorkspaceFoundation {
    package enum Surface {
        package static let material: Material = .ultraThinMaterial

        /// Very faint tint for section or summary backgrounds (replaces `Color.secondary.opacity(0.06)`).
        package static var sectionBackground: Color { Color.secondary.opacity(0.06) }

        /// Subtle fill for cards and list rows (replaces `Color.secondary.opacity(0.08)`).
        package static var cardFill: Color { Color.secondary.opacity(0.08) }

        /// Inline highlight fill for badges and manual-override indicators (replaces `Color.secondary.opacity(0.12)`).
        package static var rowHighlight: Color { Color.secondary.opacity(0.12) }

        /// Background fill for small tags and confidence-bar tracks (replaces `Color.secondary.opacity(0.14)` / `0.15`; canonical value 0.14).
        package static var tagFill: Color { Color.secondary.opacity(0.14) }

        package static var surfaceFill: Color {
            WorkspaceFoundation.dynamicColor(
                light: NSColor(calibratedRed: 0.90, green: 0.95, blue: 0.98, alpha: 0.62),
                dark: NSColor(calibratedRed: 0.14, green: 0.16, blue: 0.20, alpha: 0.62)
            )
        }

        /// Base drawing canvas — neutral, matte, full-opacity.
        package static var canvas: Color {
            WorkspaceFoundation.dynamicColor(
                light: NSColor(calibratedWhite: 0.97, alpha: 1),
                dark: NSColor(calibratedRed: 0.12, green: 0.13, blue: 0.15, alpha: 1)
            )
        }

        /// Floating overlay surface (panels, popovers) — slightly elevated, translucent.
        package static var overlay: Color {
            WorkspaceFoundation.dynamicColor(
                light: NSColor.white.withAlphaComponent(0.9),
                dark: NSColor(calibratedWhite: 0.08, alpha: 0.8)
            )
        }

        /// Raised card or panel surface — one step above canvas.
        package static var raised: Color {
            WorkspaceFoundation.dynamicColor(
                light: NSColor(calibratedWhite: 1, alpha: 0.88),
                dark: NSColor(calibratedWhite: 0.14, alpha: 1)
            )
        }
    }

    package enum Foreground {
        package static var primaryLabel: Color {
            .primary
        }

        package static var secondaryLabel: Color {
            Color(nsColor: .secondaryLabelColor)
        }

        package static var destructiveForeground: Color {
            Color(nsColor: .systemRed)
        }

        /// Foreground color for disabled interactive controls.
        /// Replaces raw `.opacity(0.55)` so WCAG contrast is auditable by token.
        package static var disabledForeground: Color {
            Color(nsColor: .tertiaryLabelColor)
        }
    }

    package enum Stroke {
        package static var divider: Color {
            Color(nsColor: .separatorColor).opacity(0.35)
        }

        package static var interactiveHoverStroke: Color {
            WorkspaceFoundation.dynamicColor(
                light: NSColor.black.withAlphaComponent(0.08),
                dark: NSColor.white.withAlphaComponent(0.12)
            )
        }

        package static var interactiveIdleStroke: Color {
            WorkspaceFoundation.dynamicColor(
                light: NSColor.black.withAlphaComponent(0.03),
                dark: NSColor.white.withAlphaComponent(0.05)
            )
        }

        package static var destructiveHoverStroke: Color {
            Color(nsColor: .systemRed).opacity(0.42)
        }

        /// Border stroke for small tag/badge overlays (replaces `Color.secondary.opacity(0.3)`).
        package static var tagBorder: Color { Color.secondary.opacity(0.3) }

        /// Stroke color for focus rings on text-input controls (e.g. InlineRenameField).
        /// Lower-opacity variant of selection accent so the ring reads as focus, not selection.
        package static var focusRingStroke: Color {
            Color.accentColor.opacity(0.75)
        }
    }

    package enum Selection {
        package static var selectionAccent: Color {
            Color.accentColor.opacity(0.95)
        }
    }

    package enum Interaction {
        package static var interactiveHoverFill: Color {
            WorkspaceFoundation.dynamicColor(
                light: NSColor.black.withAlphaComponent(0.06),
                dark: NSColor.white.withAlphaComponent(0.08)
            )
        }

        package static var interactivePressedFill: Color {
            WorkspaceFoundation.dynamicColor(
                light: NSColor.black.withAlphaComponent(0.1),
                dark: NSColor.white.withAlphaComponent(0.14)
            )
        }

        package static var destructiveHoverFill: Color {
            Color(nsColor: .systemRed).opacity(0.12)
        }

        /// Background fill for disabled controls (transparent — no fill by default).
        package static var disabledFill: Color {
            .clear
        }
    }

    package enum Metrics {
        // 4-pt grid steps
        package static let space1: CGFloat = 4
        package static let space2: CGFloat = 8
        package static let space2_5: CGFloat = 10
        package static let space3: CGFloat = 12
        package static let space3_5: CGFloat = 14
        package static let space4: CGFloat = 16
        package static let space5: CGFloat = 20
        package static let space6: CGFloat = 24
        package static let space7: CGFloat = 28

        // Sub-grid steps (off-grid legacy; preserved for WCAG/density audit — do not promote to 4-pt grid)
        package static let microSpace0_5: CGFloat = 2   // 2pt micro-gap; used in dense list rows
        package static let microSpace0_75: CGFloat = 3  // 3pt micro-gap; used in badge vertical insets
        package static let microSpace1_75: CGFloat = 7  // 7pt micro-gap; used in badge/row horizontal insets

        // Backward-compatible aliases (do not remove)
        package static let edgePadding: CGFloat = space5          // was 20; aliased to space5
        // Off-grid legacy value; preserved to avoid visual regression.
        // TODO: snap to space2 in a follow-up after audit confirms the change is acceptable and no regressions.
        package static let compactControlPadding: CGFloat = 6

        // Corner radii (unchanged)
        package static let compactControlCornerRadius: CGFloat = 9
        package static let rowCornerRadius: CGFloat = 12
        package static let cardCornerRadius: CGFloat = 14
        package static let footerButtonCornerRadius: CGFloat = 10
        package static let footerButtonHeight: CGFloat = 34
    }

    package enum Typography {
        /// Body-weight label matching the primary text ramp.
        package static let primaryLabel: Font = .body

        /// Smaller, supporting text label (callout size).
        package static let secondaryLabel: Font = .callout

        /// Small annotation text (badges, inline hints).
        package static let caption: Font = .caption

        /// Section headers — heavier than caption, lighter than body.
        package static let sectionHeader: Font = .subheadline.weight(.semibold)

        /// Fixed-width numeric font for frame numbers, timecodes, and counters.
        /// Uses `.monospacedDigit()` so digit widths are stable across value changes.
        package static let metaNumeric: Font = .caption.monospacedDigit()
    }

    package enum Shell {
        private static let darkWorkspaceNeutral = NSColor(
            calibratedRed: 0.094,
            green: 0.094,
            blue: 0.094,
            alpha: 1
        )

        package static var background: Color {
            WorkspaceFoundation.dynamicColor(
                light: NSColor(calibratedWhite: 0.985, alpha: 1),
                dark: darkWorkspaceNeutral
            )
        }

        package static var stroke: Color {
            WorkspaceFoundation.dynamicColor(
                light: NSColor.black.withAlphaComponent(0.08),
                dark: NSColor.white.withAlphaComponent(0.12)
            )
        }

        package static var shadow: Color {
            WorkspaceFoundation.dynamicColor(
                light: NSColor.black.withAlphaComponent(0.12),
                dark: NSColor.black.withAlphaComponent(0.28)
            )
        }

        package static var dividerNSColor: NSColor {
            WorkspaceFoundation.dynamicNSColor(
                light: NSColor.black.withAlphaComponent(0.1),
                dark: NSColor.white.withAlphaComponent(0.1)
            )
        }

        package static var divider: Color {
            Color(nsColor: dividerNSColor)
        }
    }

    private static func dynamicColor(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: dynamicNSColor(light: light, dark: dark))
    }

    private static func dynamicNSColor(light: NSColor, dark: NSColor) -> NSColor {
        NSColor(name: nil) { appearance in
            switch appearance.bestMatch(from: [.darkAqua, .aqua]) {
            case .darkAqua?:
                dark
            default:
                light
            }
        }
    }
}
