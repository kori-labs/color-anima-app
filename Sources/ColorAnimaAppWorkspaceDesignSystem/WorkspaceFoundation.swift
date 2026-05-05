import AppKit
import SwiftUI

package enum WorkspaceFoundation {
    package enum Surface {
        package static let material: Material = .ultraThinMaterial

        package static var surfaceFill: Color {
            WorkspaceFoundation.dynamicColor(
                light: NSColor(calibratedRed: 0.90, green: 0.95, blue: 0.98, alpha: 0.62),
                dark: NSColor(calibratedRed: 0.14, green: 0.16, blue: 0.20, alpha: 0.62)
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
    }

    package enum Metrics {
        // 4-pt grid steps
        package static let space1: CGFloat = 4
        package static let space2: CGFloat = 8
        package static let space3: CGFloat = 12
        package static let space4: CGFloat = 16
        package static let space5: CGFloat = 20
        package static let space6: CGFloat = 24

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
