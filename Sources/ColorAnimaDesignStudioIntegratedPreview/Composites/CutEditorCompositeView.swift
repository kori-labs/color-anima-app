import SwiftUI

// Layout constants for the cut editor composite. Defined here because
// WorkspaceFoundation tokens are package-internal and unavailable to this target.
private enum CutEditorLayout {
    static let commandBarHeight: CGFloat = 58
    static let frameStripHeight: CGFloat = 88
    static let inspectorWidth: CGFloat = 280
    static let sectionPadding: CGFloat = 16
    static let cardPadding: CGFloat = 6
    static let cardWidth: CGFloat = 120
    static let cardHeight: CGFloat = 64
    static let cardCornerRadius: CGFloat = 6
    static let controlSpacing: CGFloat = 4
    static let stripSpacing: CGFloat = 4
    static let stripHPadding: CGFloat = 12
    static let barHPadding: CGFloat = 16
    static let badgeHPadding: CGFloat = 5
    static let badgeVPadding: CGFloat = 2
    static let zoomControlSpacing: CGFloat = 4
    static let zoomControlPadding: CGFloat = 12
    static let infoRowMinSpacing: CGFloat = 4
    static let actionSpacing: CGFloat = 8
    // Stroke color for unselected frame cards — avoids Color.secondary.opacity inline literal.
    static let unselectedCardStroke: Color = Color(NSColor.separatorColor)
}

/// Integrated preview: Cut Editor screen.
/// approximate: real cut editor views (CanvasViewportChrome, FrameStripCardView,
/// WorkspaceCommandBarView, WorkspaceDetailSplitView) are package-internal to
/// ColorAnimaAppWorkspaceCutEditor / ColorAnimaAppWorkspaceShell and cannot be
/// imported from a separate SPM target. This composite renders the chrome layout
/// using SwiftUI system primitives to faithfully approximate the visual structure.
struct CutEditorCompositeView: View {
    var body: some View {
        VStack(spacing: 0) {
            commandBar
            Divider()
            HStack(spacing: 0) {
                canvasArea
                Divider()
                    .frame(width: 1)
                inspectorPanel
                    .frame(width: CutEditorLayout.inspectorWidth)
            }
            .frame(maxHeight: .infinity)
            Divider()
            frameStrip
        }
        .background(Color(NSColor.windowBackgroundColor))
        .frame(minWidth: 960, minHeight: 640)
    }

    // MARK: - Command bar

    private var commandBar: some View {
        HStack(spacing: 12) {
            controlGroup(items: ["doc.badge.plus", "folder", "square.and.arrow.down"])
            Divider().frame(height: 20)
            controlGroup(items: ["play.fill", "arrow.clockwise"])
            Spacer(minLength: 0)
            Text("Cut 001 — Sequence 01")
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            controlGroup(items: ["square.and.arrow.up", "square.and.arrow.up.on.square", "photo.on.rectangle"])
        }
        .padding(.horizontal, CutEditorLayout.barHPadding)
        .frame(height: CutEditorLayout.commandBarHeight)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Canvas area

    private var canvasArea: some View {
        ZStack {
            Color(NSColor.underPageBackgroundColor)
            checkerboard
                .frame(width: 480, height: 270)
                .clipShape(RoundedRectangle(cornerRadius: CutEditorLayout.cardCornerRadius))
                .shadow(radius: 8, y: 4)
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    zoomControls
                        .padding(CutEditorLayout.zoomControlPadding)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    private var checkerboard: some View {
        Canvas { context, size in
            let tileSize: CGFloat = 12
            let cols = Int(ceil(size.width / tileSize))
            let rows = Int(ceil(size.height / tileSize))
            for row in 0 ..< rows {
                for col in 0 ..< cols {
                    let isLight = (row + col) % 2 == 0
                    let rect = CGRect(
                        x: CGFloat(col) * tileSize,
                        y: CGFloat(row) * tileSize,
                        width: tileSize,
                        height: tileSize
                    )
                    context.fill(
                        Path(rect),
                        with: .color(isLight ? Color(white: 0.85) : Color(white: 0.72))
                    )
                }
            }
        }
    }

    private var zoomControls: some View {
        HStack(spacing: CutEditorLayout.zoomControlSpacing) {
            Button(action: {}) { Image(systemName: "minus") }
                .buttonStyle(.bordered)
                .controlSize(.small)
            Text("100%")
                .font(.caption)
                .monospacedDigit()
                .frame(minWidth: 36)
            Button(action: {}) { Image(systemName: "plus") }
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
    }

    // MARK: - Inspector panel

    private var inspectorPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("Region")
                infoRow("Region ID", "R-0042")
                infoRow("Centroid", "(820, 440)")
                infoRow("Bounds", "124×88 px")
                infoRow("Assignment", "Hair — Shadow")
                Divider()
                sectionHeader("Tracking")
                infoRow("State", "Tracked (anchor)")
                infoRow("Confidence", "94%")
                infoRow("Reasons", "shape, centroid")
                Divider()
                sectionHeader("Actions")
                HStack(spacing: CutEditorLayout.actionSpacing) {
                    Button("Accept") {}
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    Button("Reassign") {}
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    Button("Clear") {}
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }
            .padding(CutEditorLayout.sectionPadding)
        }
        .background(Color(NSColor.windowBackgroundColor))
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.body)
            .fontWeight(.semibold)
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: CutEditorLayout.infoRowMinSpacing)
            Text(value)
                .font(.caption)
                .monospacedDigit()
        }
    }

    // MARK: - Frame strip

    private var frameStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: CutEditorLayout.stripSpacing) {
                ForEach(Array(stubFrames.enumerated()), id: \.offset) { index, frame in
                    frameCard(frame: frame, isSelected: index == 1)
                }
            }
            .padding(.horizontal, CutEditorLayout.stripHPadding)
        }
        .frame(height: CutEditorLayout.frameStripHeight)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private func frameCard(frame: StubFrame, isSelected: Bool) -> some View {
        VStack(alignment: .leading, spacing: CutEditorLayout.controlSpacing) {
            HStack {
                Text(frame.label)
                    .font(.caption2.weight(.semibold))
                    .monospacedDigit()
                Spacer(minLength: 0)
                Text(frame.badge)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, CutEditorLayout.badgeHPadding)
                    .padding(.vertical, CutEditorLayout.badgeVPadding)
                    .background(frame.badgeColor.opacity(0.15))
                    .foregroundStyle(frame.badgeColor)
                    .clipShape(Capsule())
            }
            Text(frame.filename)
                .font(.caption.weight(.medium))
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundStyle(.secondary)
        }
        .padding(CutEditorLayout.cardPadding)
        .frame(width: CutEditorLayout.cardWidth, height: CutEditorLayout.cardHeight)
        .overlay(
            RoundedRectangle(cornerRadius: CutEditorLayout.cardCornerRadius)
                .strokeBorder(
                    isSelected ? Color.accentColor : CutEditorLayout.unselectedCardStroke,
                    lineWidth: isSelected ? 2 : 1
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: CutEditorLayout.cardCornerRadius))
    }

    private func controlGroup(items: [String]) -> some View {
        HStack(spacing: CutEditorLayout.controlSpacing) {
            ForEach(items, id: \.self) { icon in
                Button(action: {}) {
                    Image(systemName: icon)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Stub data

    private struct StubFrame {
        let label: String
        let filename: String
        let badge: String
        let badgeColor: Color
    }

    private let stubFrames: [StubFrame] = [
        StubFrame(label: "F 001", filename: "cut_001_001.png", badge: "Ref", badgeColor: .blue),
        StubFrame(label: "F 002", filename: "cut_001_002.png", badge: "94%", badgeColor: .green),
        StubFrame(label: "F 003", filename: "cut_001_003.png", badge: "78% ⚠", badgeColor: .orange),
        StubFrame(label: "F 004", filename: "cut_001_004.png", badge: "— ?", badgeColor: .secondary),
        StubFrame(label: "F 005", filename: "cut_001_005.png", badge: "Extract", badgeColor: .secondary),
        StubFrame(label: "F 006", filename: "cut_001_006.png", badge: "91%", badgeColor: .green),
    ]
}
