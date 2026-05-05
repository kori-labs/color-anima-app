import SwiftUI
import ColorAnimaAppWorkspaceDesignSystem

/// Preview cell for `InlineRenameField`.
/// Renders the field in editing state with placeholder text "sample".
struct InlineRenameFieldCell: View {
    @State private var text = ""

    var body: some View {
        InlineRenameField(
            text: $text,
            placeholder: "sample",
            onCommit: {},
            onCancel: {}
        )
        .frame(maxWidth: 300)
    }
}
