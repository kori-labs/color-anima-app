import ColorAnimaAppWorkspaceApplication
import SwiftUI

package struct RenderSettingsView: View {
    let settings: RenderSettingsModel
    let onUpdate: (RenderSettingsModel) -> Void

    package init(settings: RenderSettingsModel, onUpdate: @escaping (RenderSettingsModel) -> Void) {
        self.settings = settings
        self.onUpdate = onUpdate
    }

    package var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Format", selection: Binding(
                get: { settings.outputFormat },
                set: { newValue in
                    var copy = settings
                    copy.outputFormat = newValue
                    onUpdate(copy)
                }
            )) {
                ForEach(RenderOutputFormat.allCases, id: \.self) { format in
                    Text(format.rawValue.uppercased()).tag(format)
                }
            }
            .pickerStyle(.menu)

            VStack(alignment: .leading, spacing: 4) {
                Text("Quality")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Slider(value: Binding(
                    get: { settings.quality },
                    set: { newValue in
                        var copy = settings
                        copy.quality = newValue
                        onUpdate(copy)
                    }
                ), in: 0.0...1.0)
            }

            Picker("Resolution", selection: Binding(
                get: { settings.resolutionScale },
                set: { newValue in
                    var copy = settings
                    copy.resolutionScale = newValue
                    onUpdate(copy)
                }
            )) {
                Text("0.5x").tag(0.5)
                Text("1x").tag(1.0)
                Text("2x").tag(2.0)
            }
            .pickerStyle(.menu)
        }
    }
}
