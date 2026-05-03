import AppKit
import ColorAnimaAppWorkspaceApplication
import SwiftUI

package enum MacOSColorBridge {
    package static func rgbaColor(from color: Color) -> RGBAColor? {
        guard let nsColor = NSColor(color).usingColorSpace(.deviceRGB) else {
            return nil
        }

        return RGBAColor(
            red: Double(nsColor.redComponent),
            green: Double(nsColor.greenComponent),
            blue: Double(nsColor.blueComponent),
            alpha: Double(nsColor.alphaComponent)
        )
    }
}
