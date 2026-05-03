import AppKit

@MainActor
package enum WindowFillController {
    private static var previousFrames: [ObjectIdentifier: NSRect] = [:]

    static func toggleFill(for window: NSWindow) {
        guard let screen = resolvedScreen(for: window) else {
            window.zoom(nil)
            return
        }

        let targetFrame = screen.visibleFrame
        let windowKey = ObjectIdentifier(window)

        if window.frame.isApproximatelyEqual(to: targetFrame) {
            guard let previousFrame = previousFrames[windowKey] else {
                return
            }

            window.setFrame(previousFrame, display: true, animate: true)
            previousFrames.removeValue(forKey: windowKey)
            return
        }

        previousFrames[windowKey] = window.frame
        window.setFrame(targetFrame, display: true, animate: true)
    }

    private static func resolvedScreen(for window: NSWindow) -> NSScreen? {
        if let windowScreen = window.screen {
            return windowScreen
        }

        return NSScreen.screens.first(where: { $0.frame.intersects(window.frame) }) ?? NSScreen.main
    }
}

private extension NSRect {
    func isApproximatelyEqual(to other: NSRect, tolerance: CGFloat = 2) -> Bool {
        abs(origin.x - other.origin.x) <= tolerance &&
        abs(origin.y - other.origin.y) <= tolerance &&
        abs(size.width - other.size.width) <= tolerance &&
        abs(size.height - other.size.height) <= tolerance
    }
}
