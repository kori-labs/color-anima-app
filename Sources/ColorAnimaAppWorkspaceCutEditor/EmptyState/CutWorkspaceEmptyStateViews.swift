import ColorAnimaAppWorkspaceApplication
import ColorAnimaAppWorkspaceDesignSystem
import SwiftUI

package struct EmptyCutWorkspacePlaceholderView: View {
    let resolution: ProjectCanvasResolution

    package init(resolution: ProjectCanvasResolution) {
        self.resolution = resolution
    }

    private var aspectRatio: CGFloat {
        CGFloat(resolution.width) / CGFloat(resolution.height)
    }

    package var body: some View {
        VStack(spacing: 18) {
            CheckerboardPlaceholderSurface()
                .aspectRatio(aspectRatio, contentMode: .fit)
                .frame(maxWidth: 760)
                .shadow(color: WorkspaceChromeStyle.elevatedShadow, radius: 16, y: 10)

            VStack(spacing: 4) {
                Text("No outline loaded yet.")
                    .font(.title3.weight(.semibold))
                Text("Import an outline to begin this cut.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text("Project canvas \(resolution.width)×\(resolution.height)")
                    .font(.caption)
                    .foregroundStyle(WorkspaceChromeStyle.treeMetaLabel)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

package struct CutWorkspaceOnboardingSheet: View {
    @Environment(\.dismiss) private var dismiss

    package init() {}

    package var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Start with an outline frame")
                    .font(.title.bold())
                Text("Import an outline first, then click Extract to scan regions and bring in highlight and shadow lines when you are ready to preview them together.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 12) {
                OnboardingStepCard(number: "1", title: "Outline", subtitle: "closed area source")
                OnboardingStepCard(number: "2", title: "Scan", subtitle: "press when ready")
                OnboardingStepCard(number: "3", title: "Assign", subtitle: "subset mapping")
                OnboardingStepCard(number: "4", title: "Preview", subtitle: "base / line check")
            }

            HStack {
                Spacer()

                Button("Close") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(minWidth: 860, minHeight: 320)
        .background(WorkspaceChromeStyle.cardFill)
    }
}

private struct CheckerboardPlaceholderSurface: View {
    var body: some View {
        Canvas { context, size in
            let tileSize = CanvasPreviewDecorationMetrics.checkerboardTileSize(
                for: CGRect(origin: .zero, size: size)
            )
            let rows = Int(ceil(size.height / tileSize))
            let columns = Int(ceil(size.width / tileSize))

            for row in 0..<rows {
                for column in 0..<columns {
                    let tileRect = CGRect(
                        x: CGFloat(column) * tileSize,
                        y: CGFloat(row) * tileSize,
                        width: tileSize,
                        height: tileSize
                    )
                    let color = (row + column).isMultiple(of: 2)
                        ? WorkspaceChromeStyle.checkerboardLight
                        : WorkspaceChromeStyle.checkerboardDark
                    context.fill(Path(tileRect), with: .color(color))
                }
            }
        }
        .overlay {
            Rectangle()
                .strokeBorder(WorkspaceChromeStyle.cardStroke, lineWidth: 1)
        }
    }
}

private struct OnboardingStepCard: View {
    let number: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(number)
                .font(.caption.weight(.bold))
                .foregroundStyle(WorkspaceChromeStyle.pipelineIndex)
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(WorkspaceChromeStyle.badgeFill)
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(WorkspaceChromeStyle.cardStroke, lineWidth: 1)
        }
        .clipShape(.rect(cornerRadius: 14))
    }
}
