import ColorAnimaAppWorkspaceApplication

extension CutAssetKind {
    package var title: String {
        switch self {
        case .outline:
            "Outline"
        case .highlightLine:
            "Highlight Line"
        case .shadowLine:
            "Shadow Line"
        }
    }
}
