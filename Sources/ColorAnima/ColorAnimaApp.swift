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

    var body: some Scene {
        WindowGroup(AppShellMetadata.displayName) {
            PublicShellView()
                .frame(minWidth: 720, minHeight: 420)
        }
        .windowResizability(.contentMinSize)
    }
}

private struct PublicShellView: View {
    var body: some View {
        WorkspaceView()
    }
}
