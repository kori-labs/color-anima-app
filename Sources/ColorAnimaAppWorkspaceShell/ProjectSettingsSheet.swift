import ColorAnimaAppWorkspaceApplication
import SwiftUI

package struct ProjectSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss

    let isRequired: Bool
    let onApply: (ProjectCanvasResolution, Int) -> Void
    let onCancel: () -> Void

    @State private var draft: ProjectSettingsDraft
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case width
        case height
        case fps
    }

    package init(
        initialResolution: ProjectCanvasResolution,
        initialPlaybackFPS: Int,
        isRequired: Bool,
        onApply: @escaping (ProjectCanvasResolution, Int) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.isRequired = isRequired
        self.onApply = onApply
        self.onCancel = onCancel
        _draft = State(
            initialValue: ProjectSettingsDraft(
                initialResolution: initialResolution,
                initialPlaybackFPS: initialPlaybackFPS
            )
        )
    }

    package var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text(isRequired ? "Set Project Settings" : "Project Settings")
                    .font(.title2.bold())
                Text(descriptionText)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 16) {
                settingField(title: "Width", text: $draft.widthText, field: .width)
                settingField(title: "Height", text: $draft.heightText, field: .height)
            }

            HStack(spacing: 16) {
                settingField(title: "FPS", text: $draft.fpsText, field: .fps)
                Spacer(minLength: 0)
            }

            Text("New outline, highlight, and shadow imports must match this resolution exactly, and playback uses the selected FPS.")
                .font(.callout)
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            HStack {
                if !isRequired {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                    .keyboardShortcut(.cancelAction)
                }

                Spacer()

                Button("Apply") {
                    guard let parsedResolution = draft.parsedResolution,
                          let parsedPlaybackFPS = draft.parsedPlaybackFPS else { return }
                    onApply(parsedResolution, parsedPlaybackFPS)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(draft.parsedResolution == nil || draft.parsedPlaybackFPS == nil)
            }
        }
        .padding(24)
        .frame(minWidth: 420, minHeight: 320)
        .onAppear {
            DispatchQueue.main.async {
                focusedField = .width
            }
        }
    }

    private var descriptionText: String {
        if isRequired {
            return "This project does not have saved project settings yet. Set them once so empty cuts, new imports, and playback share the same defaults."
        }

        return "Adjust the default canvas size and playback FPS for empty cuts and future artwork imports."
    }

    private func settingField(title: String, text: Binding<String>, field: Field) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            TextField(title, text: text)
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: field)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
