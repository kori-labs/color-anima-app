import AppKit
import ColorAnimaAppShell
import ColorAnimaAppWorkspace
import SwiftUI

final class AppActivationDelegate: NSObject, NSApplicationDelegate {
    @MainActor
    private func applyWindowConfiguration(to window: NSWindow) {
        window.styleMask.insert(.fullSizeContentView)
        window.toolbarStyle = .unifiedCompact
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.toolbar?.showsBaselineSeparator = false
    }

    @MainActor
    private func configureMainWindow(retryCount: Int = 12) {
        guard let window = NSApp.windows.first else {
            guard retryCount > 0 else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.configureMainWindow(retryCount: retryCount - 1)
            }
            return
        }

        applyWindowConfiguration(to: window)
    }

    func applicationDidFinishLaunching(_: Notification) {
        NSApp.setActivationPolicy(.regular)
        DispatchQueue.main.async {
            self.configureMainWindow()
            NSRunningApplication.current.activate(options: [])
            NSApp.windows.first?.makeKeyAndOrderFront(nil)
        }
    }
}

@main
struct ColorAnimaApp: App {
    @NSApplicationDelegateAdaptor(AppActivationDelegate.self) private var appActivationDelegate
    @FocusedValue(\.engineStatusSheetTrigger) private var engineStatusSheetTrigger

    // Frame bumped from 720x420 to 720x480: the new IntakeChrome footer plus
    // header + card body needs vertical breathing room; 420 felt cramped on
    // macOS 14 once the alert/Re-check controls render in the offline card.
    var body: some Scene {
        WindowGroup(AppShellMetadata.displayName) {
            PublicShellView()
                .frame(minWidth: 720, minHeight: 480)
        }
        .windowResizability(.contentMinSize)
        .commands {
            CommandMenu("Engine") {
                Button("Engine Status…") {
                    engineStatusSheetTrigger?()
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .disabled(engineStatusSheetTrigger == nil)
            }
        }
    }
}

// Per-window sheet state. Each WindowGroup-spawned window owns its own
// `showSheet` flag so the menu command toggles the focused window's sheet
// only — App-scoped state would propagate to every open window.
private struct PublicShellView: View {
    @State private var showSheet = false

    var body: some View {
        EngineLinkGate()
            .sheet(isPresented: $showSheet) {
                EngineStatusSheet(isPresented: $showSheet)
            }
            .focusedValue(\.engineStatusSheetTrigger, { showSheet = true })
    }
}

private struct EngineStatusSheetTriggerKey: FocusedValueKey {
    typealias Value = () -> Void
}

extension FocusedValues {
    fileprivate var engineStatusSheetTrigger: EngineStatusSheetTriggerKey.Value? {
        get { self[EngineStatusSheetTriggerKey.self] }
        set { self[EngineStatusSheetTriggerKey.self] = newValue }
    }
}
