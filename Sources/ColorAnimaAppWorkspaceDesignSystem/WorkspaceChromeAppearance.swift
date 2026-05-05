import AppKit
import SwiftUI

package enum WorkspaceChromeAppearance {
    private static let darkWorkspaceNeutral = NSColor(
        calibratedRed: 0.094,
        green: 0.094,
        blue: 0.094,
        alpha: 1
    )

    package static var darkNeutralBackground: NSColor {
        darkWorkspaceNeutral
    }

    package static func dynamicColor(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: dynamicNSColor(light: light, dark: dark))
    }

    package static func dynamicColor(
        light: @escaping (NSAppearance) -> NSColor,
        dark: @escaping (NSAppearance) -> NSColor
    ) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            switch appearance.bestMatch(from: [.darkAqua, .aqua]) {
            case .darkAqua?:
                dark(appearance)
            default:
                light(appearance)
            }
        })
    }

    package static func resolvedColor(
        _ color: NSColor,
        alpha: CGFloat,
        in appearance: NSAppearance
    ) -> NSColor {
        var resolved = color
        appearance.performAsCurrentDrawingAppearance {
            resolved = color.usingType(.componentBased) ?? color
        }
        return resolved.withAlphaComponent(alpha)
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
