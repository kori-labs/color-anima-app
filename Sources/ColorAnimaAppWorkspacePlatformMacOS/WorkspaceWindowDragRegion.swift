import AppKit
import SwiftUI

package struct WorkspaceWindowDragRegion: NSViewRepresentable {
    package init() {}

    package func makeNSView(context: Context) -> WorkspaceWindowDragRegionNSView {
        WorkspaceWindowDragRegionNSView()
    }

    package func updateNSView(_ nsView: WorkspaceWindowDragRegionNSView, context: Context) {
    }
}

package final class WorkspaceWindowDragRegionNSView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    package override func mouseDown(with event: NSEvent) {
        guard let window else {
            super.mouseDown(with: event)
            return
        }

        if event.clickCount == 2 {
            Task { @MainActor in
                WindowFillController.toggleFill(for: window)
            }
            return
        }

        window.performDrag(with: event)
    }
}
