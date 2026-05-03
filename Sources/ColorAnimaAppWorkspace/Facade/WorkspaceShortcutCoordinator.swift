import AppKit
import ColorAnimaAppWorkspaceApplication
import SwiftUI

package struct WorkspaceShortcutCoordinator {
    private let definitions: [WorkspaceShortcutDefinition]

    package init(definitions: [WorkspaceShortcutDefinition] = WorkspaceShortcutDefinition.catalog) {
        self.definitions = definitions
    }

    package func resolveMoveCommand(
        _ direction: MoveCommandDirection,
        context: WorkspaceShortcutContext
    ) -> WorkspaceShortcutCommand? {
        guard canDispatchGlobalShortcut(in: context) else {
            return nil
        }

        let binding: WorkspaceShortcutBinding
        switch direction {
        case .left:
            binding = .moveCommand(.left)
        case .right:
            binding = .moveCommand(.right)
        default:
            return nil
        }

        return command(matching: binding)
    }

    package func resolveKeyDown(
        keyCode: UInt16,
        modifierFlags: NSEvent.ModifierFlags,
        context: WorkspaceShortcutContext
    ) -> WorkspaceShortcutCommand? {
        guard canDispatchGlobalShortcut(in: context) else {
            return nil
        }

        let deviceIndependentFlags = modifierFlags.intersection(.deviceIndependentFlagsMask)
        let disallowedFlags: NSEvent.ModifierFlags = [.command, .shift, .option, .control]
        guard deviceIndependentFlags.intersection(disallowedFlags).isEmpty else {
            return nil
        }

        return command(matching: .keyDown(keyCode: keyCode))
    }

    private func canDispatchGlobalShortcut(in context: WorkspaceShortcutContext) -> Bool {
        guard context.isModalPresented == false else {
            return false
        }

        guard context.isTextInputFocused == false else {
            return false
        }

        return context.hasActiveCut
    }

    private func command(matching binding: WorkspaceShortcutBinding) -> WorkspaceShortcutCommand? {
        definitions
            .first { definition in
                definition.ownership == .globalCoordinator &&
                definition.bindings.contains(binding)
            }?
            .command
    }
}

package struct WorkspaceShortcutMonitor: NSViewRepresentable {
    let coordinator: WorkspaceShortcutCoordinator
    let contextProvider: (NSWindow?) -> WorkspaceShortcutContext
    let onCommand: (WorkspaceShortcutCommand) -> Void

    package func makeNSView(context: Context) -> WorkspaceShortcutMonitorView {
        let view = WorkspaceShortcutMonitorView()
        view.coordinator = coordinator
        view.contextProvider = contextProvider
        view.onCommand = onCommand
        return view
    }

    package func updateNSView(_ nsView: WorkspaceShortcutMonitorView, context: Context) {
        nsView.coordinator = coordinator
        nsView.contextProvider = contextProvider
        nsView.onCommand = onCommand
    }

    package static func dismantleNSView(_ nsView: WorkspaceShortcutMonitorView, coordinator: ()) {
        nsView.removeEventMonitor()
    }
}

package final class WorkspaceShortcutMonitorView: NSView {
    var coordinator = WorkspaceShortcutCoordinator()
    var contextProvider: (NSWindow?) -> WorkspaceShortcutContext = { _ in
        WorkspaceShortcutContext(hasActiveCut: false, isModalPresented: false, isTextInputFocused: false)
    }
    var onCommand: (WorkspaceShortcutCommand) -> Void = { _ in }

    private var eventMonitor: Any?

    override package func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        installEventMonitorIfNeeded()
    }

    override package func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)
        if newWindow == nil {
            removeEventMonitor()
        }
    }

    override package func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    package func removeEventMonitor() {
        guard let eventMonitor else { return }
        NSEvent.removeMonitor(eventMonitor)
        self.eventMonitor = nil
    }

    private func installEventMonitorIfNeeded() {
        guard window != nil, eventMonitor == nil else { return }

        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self else { return event }
            return self.handle(event)
        }
    }

    private func handle(_ event: NSEvent) -> NSEvent? {
        guard shouldConsumeEvents(for: window) else {
            return event
        }

        let context = contextProvider(window)
        guard let command = coordinator.resolveKeyDown(
            keyCode: event.keyCode,
            modifierFlags: event.modifierFlags,
            context: context
        ) else {
            return event
        }

        DispatchQueue.main.async { [weak self] in
            self?.onCommand(command)
        }
        return nil
    }

    package func shouldConsumeEvents(for window: NSWindow?) -> Bool {
        window?.isKeyWindow == true
    }
}
