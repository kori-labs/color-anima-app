import SwiftUI

package struct HoverDeleteConfirmButton: View {
    let isVisible: Bool
    let resetToken: AnyHashable?
    let onConfirm: () -> Void

    @State private var isArmed = false

    package init(
        isVisible: Bool,
        resetToken: AnyHashable? = nil,
        onConfirm: @escaping () -> Void
    ) {
        self.isVisible = isVisible
        self.resetToken = resetToken
        self.onConfirm = onConfirm
    }

    package var body: some View {
        if isVisible || isArmed {
            Button(action: handleTap) {
                if isArmed {
                    Text("Confirm")
                        .lineLimit(1)
                } else {
                    Image(systemName: "trash")
                        .font(.caption.weight(.semibold))
                        .frame(width: 14, height: 14)
                }
            }
            .accessibilityLabel(isArmed ? "Confirm deletion" : "Delete")
            .accessibilityHint(isArmed ? "Permanently deletes the item" : "Prepares to delete the item")
            .buttonStyle(buttonStyle)
            .transition(.move(edge: .trailing).combined(with: .opacity))
            .animation(.easeOut(duration: 0.12), value: isVisible)
            .animation(.easeOut(duration: 0.12), value: isArmed)
            .onChange(of: resetToken) {
                disarm()
            }
        }
    }

    private var buttonStyle: ChromeButtonStyle {
        ChromeButtonStyle(
            isDestructive: isArmed,
            horizontalPadding: isArmed ? 10 : 6,
            verticalPadding: 5,
            cornerRadius: 8,
            font: .caption.weight(.semibold),
            idleForegroundStyle: isArmed
                ? WorkspaceFoundation.Foreground.destructiveForeground
                : WorkspaceFoundation.Foreground.secondaryLabel,
            hoverForegroundStyle: isArmed
                ? WorkspaceFoundation.Foreground.destructiveForeground
                : WorkspaceFoundation.Foreground.primaryLabel
        )
    }

    private func handleTap() {
        guard isArmed else {
            isArmed = true
            return
        }

        isArmed = false
        onConfirm()
    }

    private func disarm() {
        guard isArmed else { return }
        isArmed = false
    }
}
