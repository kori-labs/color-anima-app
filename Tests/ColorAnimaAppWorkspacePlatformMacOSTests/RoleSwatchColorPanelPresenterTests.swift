import AppKit
import SwiftUI
import XCTest
@testable import ColorAnimaAppWorkspaceCutEditor
@testable import ColorAnimaAppWorkspacePlatformMacOS

@MainActor
final class RoleSwatchColorPanelPresenterTests: XCTestCase {
    func testMacOSRoleSwatchColorPanelPresenterSeedsPanelWithCurrentColor() {
        let panel = RecordingMacOSSwatchColorPanelController()
        let presenter = MacOSRoleSwatchColorPanelPresenter(colorPanel: panel)
        let expectedColor = Color(red: 0.2, green: 0.4, blue: 0.6, opacity: 0.8)

        presenter.present(selection: .constant(expectedColor))

        XCTAssertTrue(panel.didPresent)
        XCTAssertEqual(panel.colorComponents, colorComponents(expectedColor))
        XCTAssertNotNil(panel.onColorChange)
    }

    func testMacOSRoleSwatchColorPanelPresenterWritesPanelChangesBackToBinding() {
        let panel = RecordingMacOSSwatchColorPanelController()
        let presenter = MacOSRoleSwatchColorPanelPresenter(colorPanel: panel)
        var storedColor = Color.clear
        let binding = Binding(
            get: { storedColor },
            set: { storedColor = $0 }
        )

        presenter.present(selection: binding)
        panel.emitColorChange()
        panel.color = NSColor(calibratedRed: 0.8, green: 0.25, blue: 0.1, alpha: 0.65)
        panel.emitColorChange()

        XCTAssertEqual(colorComponents(storedColor), colorComponents(Color(nsColor: panel.color)))
    }

    func testMacOSRoleSwatchColorPanelPresenterDefersPanelCreationUntilPresentation() {
        let panel = RecordingMacOSSwatchColorPanelController()
        var didCreatePanel = false

        func makePanel() -> any MacOSRoleSwatchColorPanelControlling {
            didCreatePanel = true
            return panel
        }

        let presenter = MacOSRoleSwatchColorPanelPresenter(colorPanel: makePanel())

        XCTAssertFalse(didCreatePanel)

        presenter.present(selection: .constant(.red))

        XCTAssertTrue(didCreatePanel)
        XCTAssertTrue(panel.didPresent)
    }

    func testMacOSRoleSwatchColorPanelPresenterSyncVisiblePanelRebindsSelectionAndSeedsPanelColor() {
        let panel = RecordingMacOSSwatchColorPanelController()
        let presenter = MacOSRoleSwatchColorPanelPresenter(colorPanel: panel)
        var initialColor = Color.red
        let initialBinding = Binding(
            get: { initialColor },
            set: { initialColor = $0 }
        )
        let reboundColor = Color(red: 0.1, green: 0.3, blue: 0.7, opacity: 0.6)
        var reboundStorage = reboundColor
        let reboundBinding = Binding(
            get: { reboundStorage },
            set: { reboundStorage = $0 }
        )

        presenter.present(selection: initialBinding)
        presenter.syncVisiblePanel(selection: reboundBinding)

        XCTAssertEqual(panel.presentCallCount, 1)
        XCTAssertEqual(panel.colorComponents, colorComponents(reboundColor))
        XCTAssertNotNil(panel.onColorChange)
    }

    func testMacOSRoleSwatchColorPanelPresenterSyncVisiblePanelDoesNothingWhenPanelIsHidden() {
        let panel = RecordingMacOSSwatchColorPanelController()
        let presenter = MacOSRoleSwatchColorPanelPresenter(colorPanel: panel)
        let initialColor = Color(red: 0.2, green: 0.4, blue: 0.6, opacity: 1)
        let reboundColor = Color(red: 0.9, green: 0.1, blue: 0.2, opacity: 0.5)

        presenter.present(selection: .constant(initialColor))
        panel.isVisible = false

        presenter.syncVisiblePanel(selection: Binding.constant(reboundColor))

        XCTAssertEqual(panel.presentCallCount, 1)
        XCTAssertEqual(panel.colorComponents, colorComponents(initialColor))
    }

    func testMacOSRoleSwatchColorPanelPresenterWritesPanelChangesToReboundSelection() {
        let panel = RecordingMacOSSwatchColorPanelController()
        let presenter = MacOSRoleSwatchColorPanelPresenter(colorPanel: panel)
        var firstColor = Color.red
        let firstBinding = Binding(
            get: { firstColor },
            set: { firstColor = $0 }
        )
        var secondColor = Color.blue
        let secondBinding = Binding(
            get: { secondColor },
            set: { secondColor = $0 }
        )

        presenter.present(selection: firstBinding)
        panel.emitColorChange()
        presenter.syncVisiblePanel(selection: secondBinding)
        panel.emitColorChange()
        panel.color = NSColor(calibratedRed: 0.8, green: 0.25, blue: 0.1, alpha: 0.65)
        panel.emitColorChange()

        XCTAssertEqual(colorComponents(firstColor), colorComponents(.red))
        XCTAssertEqual(colorComponents(secondColor), colorComponents(Color(nsColor: panel.color)))
    }

    func testMacOSRoleSwatchColorPanelPresenterSuppressesWriteBackFromProgrammaticReseed() {
        let panel = RecordingMacOSSwatchColorPanelController()
        let presenter = MacOSRoleSwatchColorPanelPresenter(colorPanel: panel)
        var initialColor = Color.red
        let initialBinding = Binding(
            get: { initialColor },
            set: { initialColor = $0 }
        )
        let reboundColor = Color.blue
        var reboundStorage = reboundColor
        let reboundBinding = Binding(
            get: { reboundStorage },
            set: { reboundStorage = $0 }
        )

        presenter.present(selection: initialBinding)
        panel.emitColorChange()
        presenter.syncVisiblePanel(selection: reboundBinding)
        panel.emitColorChange()

        XCTAssertEqual(colorComponents(reboundStorage), colorComponents(reboundColor))
    }

    func testMacOSRoleSwatchColorPanelPresenterStillWritesUserEditsAfterReseed() {
        let panel = RecordingMacOSSwatchColorPanelController()
        let presenter = MacOSRoleSwatchColorPanelPresenter(colorPanel: panel)
        var initialColor = Color.red
        let initialBinding = Binding(
            get: { initialColor },
            set: { initialColor = $0 }
        )
        let reboundColor = Color.blue
        var reboundStorage = reboundColor
        let reboundBinding = Binding(
            get: { reboundStorage },
            set: { reboundStorage = $0 }
        )

        presenter.present(selection: initialBinding)
        panel.emitColorChange()
        presenter.syncVisiblePanel(selection: reboundBinding)
        panel.emitColorChange()

        let editedColor = NSColor(calibratedRed: 0.42, green: 0.17, blue: 0.91, alpha: 0.55)
        panel.color = editedColor
        panel.emitColorChange()

        XCTAssertEqual(colorComponents(reboundStorage), colorComponents(Color(nsColor: editedColor)))
    }

    func testPresentInstallsObserverBeforeSeedWrite() {
        let panel = RecordingMacOSSwatchColorPanelController()
        let presenter = MacOSRoleSwatchColorPanelPresenter(colorPanel: panel)

        presenter.present(selection: .constant(.red))

        let ensureIndex = panel.eventLog.firstIndex(of: "ensureObservation")
        let setColorIndex = panel.eventLog.firstIndex(of: "setColor")
        XCTAssertNotNil(ensureIndex)
        XCTAssertNotNil(setColorIndex)
        if let ensureIndex, let setColorIndex {
            XCTAssertLessThan(ensureIndex, setColorIndex)
        }
    }

    func testRoleSwatchIsEditableOnlyWhenSelectionBindingExists() {
        XCTAssertFalse(RoleSwatchInteractionState(selection: nil).isEditable)
        XCTAssertTrue(RoleSwatchInteractionState(selection: .constant(.red)).isEditable)
    }

    func testRoleSwatchTracksSelectionVisualState() {
        XCTAssertTrue(RoleSwatchInteractionState(selection: .constant(.red), isSelected: true).isSelected)
        XCTAssertFalse(RoleSwatchInteractionState(selection: .constant(.red), isSelected: false).isSelected)
    }

    func testRoleSwatchSelectedStateUsesEmphasizedChromeMetrics() {
        let selected = RoleSwatchInteractionState(selection: .constant(.red), isSelected: true)
        let idle = RoleSwatchInteractionState(selection: .constant(.red), isSelected: false)

        XCTAssertEqual(selected.strokeLineWidth, 2)
        XCTAssertEqual(idle.strokeLineWidth, 1)
        XCTAssertEqual(selected.shadowOpacity, 0)
        XCTAssertEqual(idle.shadowOpacity, 0)
        XCTAssertEqual(selected.labelWeight, .semibold)
        XCTAssertEqual(idle.labelWeight, .regular)
    }
}

private final class RecordingMacOSSwatchColorPanelController: MacOSRoleSwatchColorPanelControlling {
    var color: NSColor = .clear {
        didSet { eventLog.append("setColor") }
    }
    var onColorChange: (() -> Void)?
    var isVisible = false
    private(set) var didPresent = false
    private(set) var presentCallCount = 0
    private(set) var eventLog: [String] = []

    var colorComponents: ColorComponents? {
        color.usingColorSpace(.deviceRGB).map {
            ColorComponents(
                red: Double($0.redComponent),
                green: Double($0.greenComponent),
                blue: Double($0.blueComponent),
                alpha: Double($0.alphaComponent)
            )
        }
    }

    func ensureObservation() {
        eventLog.append("ensureObservation")
    }

    func present() {
        didPresent = true
        isVisible = true
        presentCallCount += 1
    }

    func emitColorChange() {
        onColorChange?()
    }
}

private struct ColorComponents: Equatable {
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double
}

private func colorComponents(_ color: Color) -> ColorComponents? {
    NSColor(color).usingColorSpace(.deviceRGB).map {
        ColorComponents(
            red: Double($0.redComponent),
            green: Double($0.greenComponent),
            blue: Double($0.blueComponent),
            alpha: Double($0.alphaComponent)
        )
    }
}
