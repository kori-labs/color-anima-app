import AppKit
import ColorAnimaAppWorkspaceApplication
import ColorAnimaAppWorkspaceDesignSystem
import SwiftUI

package struct FrameStripCardView: View {
    let item: FrameStripCardItem
    let allFrameIDs: [UUID]
    let selectedFrameIDs: Set<UUID>
    let onSelect: (WorkspaceSelectionModifiers) -> Void
    let onAddReference: () -> Void
    let onMakeActiveReference: () -> Void
    let onRemoveReference: () -> Void
    @State private var isHovered = false

    package init(
        item: FrameStripCardItem,
        allFrameIDs: [UUID],
        selectedFrameIDs: Set<UUID>,
        onSelect: @escaping (WorkspaceSelectionModifiers) -> Void,
        onAddReference: @escaping () -> Void,
        onMakeActiveReference: @escaping () -> Void,
        onRemoveReference: @escaping () -> Void
    ) {
        self.item = item
        self.allFrameIDs = allFrameIDs
        self.selectedFrameIDs = selectedFrameIDs
        self.onSelect = onSelect
        self.onAddReference = onAddReference
        self.onMakeActiveReference = onMakeActiveReference
        self.onRemoveReference = onRemoveReference
    }

    package var body: some View {
        ZStack(alignment: .topTrailing) {
            Button {
                onSelect(selectionModifiers)
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text(item.frameLabel)
                            .font(.caption2.weight(.semibold))
                            .monospacedDigit()

                        Spacer(minLength: 0)

                        frameStatusBadgeLabel
                    }

                    Text(item.displayFilename)
                        .font(.caption.weight(.medium))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .foregroundStyle(item.isDisplayFilenamePlaceholder ? .secondary : .primary)

                    if item.showsPersistentReferenceAction {
                        persistentReferenceActionPlaceholder
                    } else {
                        Spacer(minLength: 0)
                    }
                }
                .padding(WorkspaceFoundation.Metrics.space2_5)
                .frame(width: 148, alignment: .leading)
                .frame(height: 84, alignment: .topLeading)
                .background(tileFill)
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(tileStroke, lineWidth: item.isCurrent ? 2 : 1)
                }
                .clipShape(.rect(cornerRadius: 16))
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .contentShape(.rect(cornerRadius: 16))
            .onDrag {
                let draggedIDs = dragSelectionIDs
                if item.isSelected == false {
                    onSelect([])
                }
                Task { @MainActor in
                    FrameStripDragContext.draggedFrameIDs = draggedIDs
                }
                return NSItemProvider(object: NSString(string: draggedIDs.map(\.uuidString).joined(separator: ",")))
            }

            if item.showsPersistentReferenceAction {
                persistentReferenceActionButton
                    .padding(.horizontal, WorkspaceFoundation.Metrics.space2_5)
                    .padding(.bottom, WorkspaceFoundation.Metrics.space2_5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            }

            if isHovered {
                HStack(spacing: 4) {
                    if item.isIncludedReference {
                        if item.isActiveReference == false {
                            referenceActionButton(
                                systemImage: "flag.fill",
                                label: "Make Active Reference",
                                action: onMakeActiveReference
                            )
                        }
                        referenceActionButton(
                            systemImage: "minus",
                            label: "Remove Reference",
                            action: onRemoveReference
                        )
                    }
                }
                .padding(WorkspaceFoundation.Metrics.space2)
            }
        }
        .frame(width: 148, height: 84, alignment: .topLeading)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

private extension FrameStripCardView {
    @ViewBuilder
    var frameStatusBadgeLabel: some View {
        if let trackingBadge = item.trackingBadge {
            let tint = badgeTint(for: trackingBadge)
            frameStatusBadge(trackingBadge.label, tint: tint)
        }
    }

    func frameStatusBadge(_ title: String, tint: Color) -> some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, WorkspaceFoundation.Metrics.compactControlPadding)
            .padding(.vertical, WorkspaceFoundation.Metrics.microSpace0_75)
            .background(tint.opacity(0.12))
            .foregroundStyle(tint)
            .clipShape(.capsule)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
    }

    func referenceActionButton(
        systemImage: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
                .padding(WorkspaceFoundation.Metrics.compactControlPadding)
        }
        .buttonStyle(
            ChromeButtonStyle(
                horizontalPadding: 0,
                verticalPadding: 0,
                cornerRadius: 10,
                idleForegroundStyle: WorkspaceChromeStyle.treeMetaLabel,
                hoverForegroundStyle: WorkspaceChromeStyle.selectionStroke
            )
        )
        .help(label)
        .accessibilityLabel(Text(label))
    }

    var persistentReferenceActionPlaceholder: some View {
        referenceActionLabel(systemImage: "flag.badge.plus.fill", title: "Add Reference")
            .hidden()
            .accessibilityHidden(true)
    }

    var persistentReferenceActionButton: some View {
        Button(action: onAddReference) {
            referenceActionLabel(systemImage: "flag.badge.plus.fill", title: "Add Reference")
        }
        .buttonStyle(.plain)
        .help("Add Reference")
        .accessibilityLabel(Text("Add Reference"))
    }

    func referenceActionLabel(
        systemImage: String,
        title: String
    ) -> some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.caption2.weight(.semibold))
            Text(title)
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
        }
        .padding(.horizontal, WorkspaceFoundation.Metrics.space2)
        .padding(.vertical, 5) // EXCEPTION: 5pt micro-gap used once for badge vertical inset; no matching token (space1=4, space2_5=10 are too far apart)
        .background(WorkspaceChromeStyle.badgeFill)
        .overlay {
            Capsule()
                .strokeBorder(WorkspaceChromeStyle.treeRowSelectedBorder, lineWidth: 1)
        }
        .clipShape(.capsule)
        .foregroundStyle(WorkspaceChromeStyle.treeMetaLabel)
    }

    var tileFill: Color {
        if item.isCurrent {
            return WorkspaceChromeStyle.treeRowSelectedFill
        }
        if item.isSelected {
            return WorkspaceChromeStyle.treeRowSelectedFill.opacity(0.58)
        }
        if isHovered {
            return WorkspaceChromeStyle.treeRowHoverFill
        }
        return WorkspaceChromeStyle.treeRowFill
    }

    var tileStroke: Color {
        if item.isCurrent {
            return WorkspaceChromeStyle.selectionStroke
        }
        if item.isSelected || isHovered {
            return WorkspaceChromeStyle.treeRowSelectedBorder
        }
        return WorkspaceChromeStyle.treeRowBorder
    }

    var selectionModifiers: WorkspaceSelectionModifiers {
        let modifierFlags = NSApp.currentEvent?.modifierFlags ?? []
        var modifiers = WorkspaceSelectionModifiers()
        if modifierFlags.contains(.command) {
            modifiers.insert(.additive)
        }
        if modifierFlags.contains(.shift) {
            modifiers.insert(.range)
        }
        return modifiers
    }

    var dragSelectionIDs: [UUID] {
        if item.isSelected {
            return allFrameIDs.filter { selectedFrameIDs.contains($0) }
        }
        return [item.id]
    }

    func badgeTint(for badge: FrameStripTrackingBadge) -> Color {
        switch badge.tint {
        case .green:
            return badge.state == .reference && item.isActiveReference == false
                ? WorkspaceChromeStyle.treeMetaLabel
                : .green
        case .neutral:
            return WorkspaceChromeStyle.treeMetaLabel
        case .orange:
            return .orange
        case .red:
            return .red
        case .gray:
            return .gray
        }
    }
}
