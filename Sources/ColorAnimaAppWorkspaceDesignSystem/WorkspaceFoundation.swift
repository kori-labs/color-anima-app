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
                light: NSColor(calibratedRed: 0.90, green: 0.95, blue: 0.98, alpha: 1),
                dark: NSColor(calibratedRed: 0.14, green: 0.16, blue: 0.20, alpha: 1)
            )
        }

        /// Base drawing canvas — neutral, matte, full-opacity.
        package static var canvas: Color {
            WorkspaceFoundation.dynamicColor(
                light: NSColor(calibratedWhite: 0.97, alpha: 1),
                dark: NSColor(calibratedRed: 0.12, green: 0.13, blue: 0.15, alpha: 1)
            )
        }

        /// Floating overlay surface (panels, popovers) — opaque.
        package static var overlay: Color {
            WorkspaceFoundation.dynamicColor(
                light: NSColor.white,
                dark: NSColor(calibratedWhite: 0.08, alpha: 1)
            )
        }

        /// Raised card or panel surface — one step above canvas, opaque.
        package static var raised: Color {
            WorkspaceFoundation.dynamicColor(
                light: NSColor(calibratedWhite: 1, alpha: 1),
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

    /// Geist-aligned ring tokens implementing the "shadow-as-border" philosophy
    /// (Vercel/Geist `box-shadow: 0 0 0 1px rgba(0,0,0,0.08)`). Apply via
    /// `.overlay(RoundedRectangle(cornerRadius: r).stroke(Ring.hairline, lineWidth: Ring.width))`.
    package enum Ring {
        /// Signature ring used on cards, buttons, and surfaces (Vercel `rgba(0,0,0,0.08)`).
        package static var hairline: Color {
            WorkspaceFoundation.dynamicColor(
                light: NSColor.black.withAlphaComponent(0.08),
                dark: NSColor.white.withAlphaComponent(0.10)
            )
        }

        /// Lighter ring for tabs, image cards, and nested separators (Vercel `rgb(235,235,235)`).
        package static var light: Color {
            WorkspaceFoundation.dynamicColor(
                light: NSColor(calibratedWhite: 0.92, alpha: 1),
                dark: NSColor.white.withAlphaComponent(0.06)
            )
        }

        package static let width: CGFloat = 1
    }

    /// Multi-layer card depth tokens. SwiftUI lacks a single CSS-equivalent
    /// `box-shadow` stack, so apply both layers (`.shadow(...)` chained) plus
    /// the `Ring.hairline` overlay to recreate the Geist card feel.
    package enum Elevation {
        /// Layer 1 — close lift. Vercel `rgba(0,0,0,0.04) 0 2px 2px`.
        package static var cardLiftColor: Color {
            WorkspaceFoundation.dynamicColor(
                light: NSColor.black.withAlphaComponent(0.04),
                dark: NSColor.black.withAlphaComponent(0.55)
            )
        }
        package static let cardLiftRadius: CGFloat = 2
        package static let cardLiftY: CGFloat = 2

        /// Layer 2 — far depth. Vercel `rgba(0,0,0,0.04) 0 8px 8px -8px` (approximated).
        package static var cardDepthColor: Color {
            WorkspaceFoundation.dynamicColor(
                light: NSColor.black.withAlphaComponent(0.03),
                dark: NSColor.black.withAlphaComponent(0.45)
            )
        }
        package static let cardDepthRadius: CGFloat = 8
        package static let cardDepthY: CGFloat = 6
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
        package static let microSpace1_25: CGFloat = 5  // 5pt micro-gap; used in pill/capsule badge vertical insets
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
        package static let frameCardCornerRadius: CGFloat = 16
        package static let footerButtonCornerRadius: CGFloat = 10
        package static let footerButtonHeight: CGFloat = 34

        // Geist-scale corner radii. Use these on net-new components; do not
        // retrofit existing controls without an audit.
        package static let microRadius: CGFloat = 2     // Inline code spans, micro chips.
        package static let controlRadius: CGFloat = 6   // Buttons, links, functional controls.
        package static let pillRadius: CGFloat = 9999   // Full-pill badges, status tags.

        // Opacity steps for tint-driven fills (kept as Double — SwiftUI .opacity expects Double).
        package static let badgeTintOpacity: Double = 0.12
        package static let dimSelectionOpacity: Double = 0.58
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

        // Geist-scale display tier. Apply Font + matching tracking together,
        // e.g. `.font(Typography.displayHero).tracking(Typography.displayHeroTracking)`.
        // Tracking values are points (≈ Vercel's px at default macOS density).
        // Geist fonts ship in the .app via `ATSApplicationFontsPath` (see
        // `scripts/build-macos-app.sh`). When the PostScript name is not
        // registered (CI without `.local-fonts/`), SwiftUI `.custom` falls
        // back silently to the system font.
        package static let displayHero: Font = .custom("Geist-SemiBold", size: 48)
        package static let displayHeroTracking: CGFloat = -2.4

        package static let displaySection: Font = .custom("Geist-SemiBold", size: 32)
        package static let displaySectionTracking: CGFloat = -1.28

        package static let displayCardTitle: Font = .custom("Geist-SemiBold", size: 24)
        package static let displayCardTitleTracking: CGFloat = -0.96
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

package extension View {
    /// Applies a Geist-scale display tier (font + paired tracking) in one call.
    /// Avoids the easy mistake of forgetting to pair tracking with the display font.
    func geistDisplay(_ tier: GeistDisplayTier) -> some View {
        switch tier {
        case .hero:
            return AnyView(self
                .font(WorkspaceFoundation.Typography.displayHero)
                .tracking(WorkspaceFoundation.Typography.displayHeroTracking))
        case .section:
            return AnyView(self
                .font(WorkspaceFoundation.Typography.displaySection)
                .tracking(WorkspaceFoundation.Typography.displaySectionTracking))
        case .cardTitle:
            return AnyView(self
                .font(WorkspaceFoundation.Typography.displayCardTitle)
                .tracking(WorkspaceFoundation.Typography.displayCardTitleTracking))
        }
    }
}

package enum GeistDisplayTier {
    case hero
    case section
    case cardTitle
}

package extension View {
    /// Applies the Geist card treatment: hairline ring overlay + 2-layer
    /// elevation shadow. Caller supplies the corner radius via the design-token.
    /// Use `WorkspaceFoundation.Metrics.cardCornerRadius` etc.
    func geistCard(cornerRadius: CGFloat = WorkspaceFoundation.Metrics.cardCornerRadius) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return self
            .overlay(shape.stroke(WorkspaceFoundation.Ring.hairline, lineWidth: WorkspaceFoundation.Ring.width))
            .shadow(color: WorkspaceFoundation.Elevation.cardLiftColor,
                    radius: WorkspaceFoundation.Elevation.cardLiftRadius,
                    x: 0, y: WorkspaceFoundation.Elevation.cardLiftY)
            .shadow(color: WorkspaceFoundation.Elevation.cardDepthColor,
                    radius: WorkspaceFoundation.Elevation.cardDepthRadius,
                    x: 0, y: WorkspaceFoundation.Elevation.cardDepthY)
    }
}
