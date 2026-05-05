import Foundation

/// The four integrated screen composites available in the Design Studio.
public enum IntegratedPreviewScreen: String, CaseIterable, Identifiable, Sendable {
    case intake
    case workspaceShell
    case cutEditor
    case inspector

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .intake: return "Intake"
        case .workspaceShell: return "Workspace Shell"
        case .cutEditor: return "Cut Editor"
        case .inspector: return "Inspector"
        }
    }
}
