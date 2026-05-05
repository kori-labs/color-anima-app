import SwiftUI

@main
struct DesignStudioApp: App {
    @State private var model = StudioModel()

    var body: some Scene {
        WindowGroup {
            StudioRootView(model: model)
        }
        .defaultSize(width: 1200, height: 800)
        .commands {
            CommandGroup(replacing: .undoRedo) {
                Button("Undo") { model.undo() }
                    .keyboardShortcut("z", modifiers: .command)
                    .disabled(!model.canUndo)
                Button("Redo") { model.redo() }
                    .keyboardShortcut("z", modifiers: [.command, .shift])
                    .disabled(!model.canRedo)
            }
        }
    }
}
