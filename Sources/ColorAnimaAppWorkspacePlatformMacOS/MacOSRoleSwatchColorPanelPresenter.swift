import AppKit
import ColorAnimaAppWorkspaceCutEditor
import SwiftUI

@MainActor
package protocol MacOSRoleSwatchColorPanelControlling: AnyObject {
    var color: NSColor { get set }
    var isVisible: Bool { get }
    var onColorChange: (() -> Void)? { get set }

    func ensureObservation()
    func present()
}

@MainActor
package final class MacOSNSColorPanelController: MacOSRoleSwatchColorPanelControlling {
    private lazy var panel = NSColorPanel.shared
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

    private func ensureColorChangeObservation() {
        guard colorChangeObserver == nil else {
            return
        }

        colorChangeObserver = NotificationCenter.default.addObserver(
            forName: NSColorPanel.colorDidChangeNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.onColorChange?()
            }
        }
    }

    package func ensureObservation() {
        ensureColorChangeObservation()
    }

    package func present() {
        ensureColorChangeObservation()
        panel.showsAlpha = true
        panel.isContinuous = true
        panel.makeKeyAndOrderFront(nil)
    }
}

@MainActor
package final class MacOSRoleSwatchColorPanelPresenter: NSObject, RoleSwatchColorPanelPresenting {
    package static let shared = MacOSRoleSwatchColorPanelPresenter()

    private let colorPanelFactory: () -> any MacOSRoleSwatchColorPanelControlling
    private lazy var colorPanel: any MacOSRoleSwatchColorPanelControlling = colorPanelFactory()
    private var activeSelection: Binding<Color>?
    private var pendingSeededChanges = 0

    package init(
        colorPanel: @autoclosure @escaping () -> any MacOSRoleSwatchColorPanelControlling = ColorAnimaColorPickerController()
    ) {
        colorPanelFactory = colorPanel
    }

    package func present(selection: Binding<Color>) {
        bind(selection)
        colorPanel.ensureObservation()
        seedPanelColor(from: selection)
        colorPanel.present()
    }

    package func syncVisiblePanel(selection: Binding<Color>) {
        guard colorPanel.isVisible else {
            return
        }

        bind(selection)
        let incoming = NSColor(selection.wrappedValue)
        guard incoming != colorPanel.color else { return }
        pendingSeededChanges += 1
        colorPanel.color = incoming
    }

    private func applyColorChangeFromPanel() {
        if pendingSeededChanges > 0 {
            pendingSeededChanges -= 1
            return
        }

        guard let activeSelection else {
            return
        }

        activeSelection.wrappedValue = Color(nsColor: colorPanel.color)
    }

    private func bind(_ selection: Binding<Color>) {
        activeSelection = selection
        colorPanel.onColorChange = { [weak self] in
            self?.applyColorChangeFromPanel()
        }
    }

    private func seedPanelColor(from selection: Binding<Color>) {
        pendingSeededChanges += 1
        colorPanel.color = NSColor(selection.wrappedValue)
    }
}
