import AppKit
import UniformTypeIdentifiers

package enum SaveConfirmationChoice {
    case save
    case discard
    case cancel
}

package enum FilePanels {
    @MainActor
    package static func openProjectDirectory(title: String) throws -> URL? {
        activateAppForModalInput()
        let panel = NSOpenPanel()
        panel.title = title
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        return panel.runModal() == .OK ? panel.url : nil
    }

    @MainActor
    package static func chooseProjectDirectory(title: String, suggestedName: String) throws -> URL? {
        activateAppForModalInput()
        let panel = NSSavePanel()
        panel.title = title
        panel.nameFieldStringValue = suggestedName
        panel.allowedContentTypes = []
        panel.canCreateDirectories = true
        panel.treatsFilePackagesAsDirectories = true
        return panel.runModal() == .OK ? panel.url : nil
    }

    @MainActor
    package static func openImage(title: String) throws -> URL? {
        activateAppForModalInput()
        let panel = NSOpenPanel()
        panel.title = title
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.image]
        return panel.runModal() == .OK ? panel.url : nil
    }

    @MainActor
    package static func savePNG(title: String, suggestedName: String) throws -> URL? {
        activateAppForModalInput()
        let panel = NSSavePanel()
        panel.title = title
        panel.nameFieldStringValue = suggestedName
        panel.allowedContentTypes = [.png]
        panel.canCreateDirectories = true
        return panel.runModal() == .OK ? panel.url : nil
    }

    @MainActor
    package static func saveReviewPNG() throws -> URL? {
        try savePNG(title: "Export Review PNG", suggestedName: "color-anima-preview-review")
    }

    @MainActor
    package static func saveDirectory(title: String) -> URL? {
        activateAppForModalInput()
        let panel = NSOpenPanel()
        panel.title = title
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        return panel.runModal() == .OK ? panel.url : nil
    }

    @MainActor
    package static func promptForName(title: String, message: String, defaultValue: String) throws -> String? {
        activateAppForModalInput()
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")

        let field = NSTextField(string: defaultValue)
        field.frame = NSRect(x: 0, y: 0, width: 280, height: 24)
        alert.accessoryView = field
        let window = alert.window
        window.initialFirstResponder = field
        window.makeFirstResponder(field)

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return nil }
        let trimmed = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    @MainActor
    package static func confirmDelete(title: String, message: String) throws -> Bool {
        activateAppForModalInput()
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }

    @MainActor
    package static func confirmUnsavedChanges(dirtyCutCount: Int) throws -> SaveConfirmationChoice {
        activateAppForModalInput()
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Save changes before continuing?"
        if dirtyCutCount > 0 {
            alert.informativeText = "There are unsaved changes in \(dirtyCutCount) cut(s)."
        } else {
            alert.informativeText = "There are unsaved project changes."
        }
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Don't Save")
        alert.addButton(withTitle: "Cancel")

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            return .save
        case .alertSecondButtonReturn:
            return .discard
        default:
            return .cancel
        }
    }

    @MainActor
    package static func activateAppForModalInput() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.mainWindow?.makeKeyAndOrderFront(nil)
    }
}
