import Foundation

public enum WorkspaceShortcutCommand: String, CaseIterable, Hashable, Sendable {
    case selectPreviousFrame
    case selectNextFrame
    case toggleFramePlayback
    case assignSubsetToSelectedRegions
    case applyProjectSettings
    case cancelProjectSettings
    case dismissCutOnboarding
    case submitInlineRename
    case cancelInlineRename
    case commitInlineRenameOnBlur
    case commitInlineRenameOnOutsideClick
}

public enum WorkspaceShortcutOwnership: String, Hashable, Sendable {
    case globalCoordinator
    case sheetLocal
    case textEntryLocal
}

public enum WorkspaceShortcutMoveDirection: String, Hashable, Sendable {
    case left
    case right
}

public enum WorkspaceShortcutSheetAction: String, Hashable, Sendable {
    case defaultAction
    case cancelAction
}

public enum WorkspaceShortcutTextEntryAction: String, Hashable, Sendable {
    case submit
    case escape
    case blurCommit
    case outsideClickCommit
}

public enum WorkspaceShortcutBinding: Hashable, Sendable {
    case moveCommand(WorkspaceShortcutMoveDirection)
    case keyDown(keyCode: UInt16)
    case sheetAction(WorkspaceShortcutSheetAction)
    case textEntryAction(WorkspaceShortcutTextEntryAction)
}

public struct WorkspaceShortcutDefinition: Hashable, Sendable {
    public var command: WorkspaceShortcutCommand
    public var ownership: WorkspaceShortcutOwnership
    public var label: String
    public var bindings: [WorkspaceShortcutBinding]

    public init(
        command: WorkspaceShortcutCommand,
        ownership: WorkspaceShortcutOwnership,
        label: String,
        bindings: [WorkspaceShortcutBinding]
    ) {
        self.command = command
        self.ownership = ownership
        self.label = label
        self.bindings = bindings
    }
}

public struct WorkspaceShortcutContext: Equatable, Sendable {
    public var hasActiveCut: Bool
    public var isModalPresented: Bool
    public var isTextInputFocused: Bool

    public init(
        hasActiveCut: Bool,
        isModalPresented: Bool,
        isTextInputFocused: Bool
    ) {
        self.hasActiveCut = hasActiveCut
        self.isModalPresented = isModalPresented
        self.isTextInputFocused = isTextInputFocused
    }
}

public extension WorkspaceShortcutDefinition {
    static let catalog: [WorkspaceShortcutDefinition] = [
        WorkspaceShortcutDefinition(
            command: .selectPreviousFrame,
            ownership: .globalCoordinator,
            label: "Select Previous Frame",
            bindings: [
                .moveCommand(.left),
                .keyDown(keyCode: 123),
            ]
        ),
        WorkspaceShortcutDefinition(
            command: .selectNextFrame,
            ownership: .globalCoordinator,
            label: "Select Next Frame",
            bindings: [
                .moveCommand(.right),
                .keyDown(keyCode: 124),
            ]
        ),
        WorkspaceShortcutDefinition(
            command: .toggleFramePlayback,
            ownership: .globalCoordinator,
            label: "Toggle Frame Playback",
            bindings: [.keyDown(keyCode: 49)]
        ),
        WorkspaceShortcutDefinition(
            command: .assignSubsetToSelectedRegions,
            ownership: .globalCoordinator,
            label: "Assign Subset to Selected Regions",
            bindings: [.keyDown(keyCode: 0)]
        ),
        WorkspaceShortcutDefinition(
            command: .applyProjectSettings,
            ownership: .sheetLocal,
            label: "Apply Project Settings",
            bindings: [.sheetAction(.defaultAction)]
        ),
        WorkspaceShortcutDefinition(
            command: .cancelProjectSettings,
            ownership: .sheetLocal,
            label: "Cancel Project Settings",
            bindings: [.sheetAction(.cancelAction)]
        ),
        WorkspaceShortcutDefinition(
            command: .dismissCutOnboarding,
            ownership: .sheetLocal,
            label: "Dismiss Cut Onboarding",
            bindings: [.sheetAction(.defaultAction)]
        ),
        WorkspaceShortcutDefinition(
            command: .submitInlineRename,
            ownership: .textEntryLocal,
            label: "Submit Inline Rename",
            bindings: [.textEntryAction(.submit)]
        ),
        WorkspaceShortcutDefinition(
            command: .cancelInlineRename,
            ownership: .textEntryLocal,
            label: "Cancel Inline Rename",
            bindings: [.textEntryAction(.escape)]
        ),
        WorkspaceShortcutDefinition(
            command: .commitInlineRenameOnBlur,
            ownership: .textEntryLocal,
            label: "Commit Inline Rename On Blur",
            bindings: [.textEntryAction(.blurCommit)]
        ),
        WorkspaceShortcutDefinition(
            command: .commitInlineRenameOnOutsideClick,
            ownership: .textEntryLocal,
            label: "Commit Inline Rename On Outside Click",
            bindings: [.textEntryAction(.outsideClickCommit)]
        ),
    ]

    static var globalCoordinatorCatalog: [WorkspaceShortcutDefinition] {
        catalog.filter { $0.ownership == .globalCoordinator }
    }
}
