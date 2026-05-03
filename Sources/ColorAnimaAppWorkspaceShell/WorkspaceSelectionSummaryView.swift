import ColorAnimaAppWorkspaceApplication
import ColorAnimaAppWorkspaceDesignSystem
import SwiftUI

package struct WorkspaceSelectionSummaryView: View {
    let selectedNode: WorkspaceProjectTreeNode?
    let projectName: String
    let sequenceName: String
    let sceneName: String
    let cutName: String

    package init(
        selectedNode: WorkspaceProjectTreeNode?,
        projectName: String,
        sequenceName: String,
        sceneName: String,
        cutName: String
    ) {
        self.selectedNode = selectedNode
        self.projectName = projectName
        self.sequenceName = sequenceName
        self.sceneName = sceneName
        self.cutName = cutName
    }

    package var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.largeTitle.bold())
                Text(summaryMessage)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                summaryCard(title: "Project", value: projectName, detail: "Root manifest and color system live here.")
                summaryCard(title: "Sequence", value: sequenceName, detail: "Sequences group scenes under the project.")
                summaryCard(title: "Scene", value: sceneName, detail: "Scenes group cuts inside the sequence.")
                summaryCard(title: "Cut", value: cutName, detail: "Select a cut to open the editor, canvas, and inspector.")
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("What happens next")
                    .font(.headline)
                Text("When a cut is selected, the existing canvas and inspector flow appears on the right. Non-cut selections intentionally stay read-only.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var summaryMessage: String {
        guard let selectedNode else {
            return "Select any node in the tree. Only cuts activate the editor on the right."
        }

        switch selectedNode.kind {
        case .project:
            return "Project nodes organize the global color system and the fixed sequence/scene/cut hierarchy."
        case .sequence:
            return "Sequence nodes group scenes and keep the tree organized without opening the editor."
        case .scene:
            return "Scene nodes group cuts. Select a cut to start editing the frame workspace."
        case .cut:
            return "Cuts activate the editing workspace with canvas, region extraction, and subset assignment."
        }
    }

    private var title: String {
        guard let selectedNode else {
            return "Workspace"
        }

        return nodeTitle(for: selectedNode.kind)
    }

    private func nodeTitle(for kind: WorkspaceProjectTreeNodeKind) -> String {
        switch kind {
        case .project:
            return "Project"
        case .sequence:
            return "Sequence"
        case .scene:
            return "Scene"
        case .cut:
            return "Cut"
        }
    }

    private func summaryCard(title: String, value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.secondary.opacity(0.06))
        .clipShape(.rect(cornerRadius: 14))
    }
}
