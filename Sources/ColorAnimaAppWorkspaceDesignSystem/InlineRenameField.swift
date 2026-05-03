import AppKit
import SwiftUI

package struct InlineRenameField: View {
    @Binding var text: String
    let placeholder: String
    let onCommit: () -> Void
    let onCancel: () -> Void

    @FocusState private var isFocused: Bool
    @State private var didAppear = false
    @State private var didResolve = false

    package init(
        text: Binding<String>,
        placeholder: String,
        onCommit: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        _text = text
        self.placeholder = placeholder
        self.onCommit = onCommit
        self.onCancel = onCancel
    }

    package var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .focused($isFocused)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .textBackgroundColor).opacity(0.92))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.accentColor.opacity(0.75), lineWidth: 1)
            }
            .overlay {
                ClickOutsideMonitor {
                    resolve(commit: true)
                }
                .allowsHitTesting(false)
            }
            .onAppear {
                didAppear = true
                didResolve = false
                DispatchQueue.main.async {
                    isFocused = true
                }
            }
            .onSubmit {
                resolve(commit: true)
            }
            .onChange(of: isFocused) {
                guard didAppear, !isFocused else { return }
                resolve(commit: true)
            }
            .onExitCommand {
                resolve(commit: false)
            }
    }

    private func resolve(commit: Bool) {
        guard !didResolve else { return }
        didResolve = true

        if commit {
            onCommit()
        } else {
            onCancel()
        }
    }
}

private struct ClickOutsideMonitor: NSViewRepresentable {
    let onClickOutside: () -> Void

    func makeNSView(context: Context) -> ClickOutsideMonitorView {
        let view = ClickOutsideMonitorView()
        view.onClickOutside = onClickOutside
        return view
    }

    func updateNSView(_ nsView: ClickOutsideMonitorView, context: Context) {
        nsView.onClickOutside = onClickOutside
    }

    static func dismantleNSView(_ nsView: ClickOutsideMonitorView, coordinator: ()) {
        nsView.removeEventMonitor()
    }
}

private final class ClickOutsideMonitorView: NSView {
    var onClickOutside: () -> Void = {}
    private var eventMonitor: Any?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        installEventMonitorIfNeeded()
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)
        if newWindow == nil {
            removeEventMonitor()
        }
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    func removeEventMonitor() {
        guard let eventMonitor else { return }
        NSEvent.removeMonitor(eventMonitor)
        self.eventMonitor = nil
    }

    private func installEventMonitorIfNeeded() {
        guard window != nil, eventMonitor == nil else { return }

        eventMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] event in
            guard let self, let window = self.window, event.window === window else {
                return event
            }

            let location = self.convert(event.locationInWindow, from: nil)
            guard !self.bounds.contains(location) else {
                return event
            }

            DispatchQueue.main.async { [weak self] in
                self?.onClickOutside()
            }
            return event
        }
    }
}
