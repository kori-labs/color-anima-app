import AppKit

@MainActor
package final class ColorAnimaColorPickerController: MacOSRoleSwatchColorPanelControlling {
    private static let recentColorsKey = "com.coloranima.recentSwatchColors"
    private static let maxRecentColors = 10

    private static var recentColorHexValues: [String] {
        get { UserDefaults.standard.stringArray(forKey: recentColorsKey) ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: recentColorsKey) }
    }

    private lazy var panel: NSColorPanel = {
        let panel = NSColorPanel.shared
        return panel
    }()

    private var colorChangeObserver: NSObjectProtocol?

    package var color: NSColor {
        get { panel.color }
        set { panel.color = newValue }
    }

    package var isVisible: Bool {
        panel.isVisible
    }

    package var onColorChange: (() -> Void)?

    package init() {}

    package func ensureObservation() {
        ensureColorChangeObservation()
    }

    package func present() {
        ensureColorChangeObservation()
        panel.showsAlpha = true
        panel.isContinuous = true
        panel.makeKeyAndOrderFront(nil)
    }

    private func ensureColorChangeObservation() {
        guard colorChangeObserver == nil else { return }

        colorChangeObserver = NotificationCenter.default.addObserver(
            forName: NSColorPanel.colorDidChangeNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.recordRecentColor()
                self?.onColorChange?()
            }
        }
    }

    private func recordRecentColor() {
        guard let hex = hexString(from: panel.color) else { return }

        var recent = Self.recentColorHexValues
        recent.removeAll { $0 == hex }
        recent.insert(hex, at: 0)
        if recent.count > Self.maxRecentColors {
            recent = Array(recent.prefix(Self.maxRecentColors))
        }
        Self.recentColorHexValues = recent
    }

    private func hexString(from nsColor: NSColor) -> String? {
        guard let srgb = nsColor.usingColorSpace(.deviceRGB) else { return nil }
        let red = Int((srgb.redComponent * 255).rounded())
        let green = Int((srgb.greenComponent * 255).rounded())
        let blue = Int((srgb.blueComponent * 255).rounded())
        let alpha = Int((srgb.alphaComponent * 255).rounded())
        return String(format: "%02x%02x%02x%02x", red, green, blue, alpha)
    }
}
