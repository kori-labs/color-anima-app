import AppKit
import SwiftUI
import XCTest
@testable import ColorAnimaAppWorkspace
@testable import ColorAnimaAppWorkspaceApplication

final class WorkspaceShortcutCoordinatorTests: XCTestCase {
    func testShortcutCatalogListsGlobalAndLocalOwnership() {
        let definitions = WorkspaceShortcutDefinition.catalog

        XCTAssertEqual(
            Set(definitions.map(\.command)),
            [
                .selectPreviousFrame,
                .selectNextFrame,
                .toggleFramePlayback,
                .assignSubsetToSelectedRegions,
                .applyProjectSettings,
                .cancelProjectSettings,
                .dismissCutOnboarding,
                .submitInlineRename,
                .cancelInlineRename,
                .commitInlineRenameOnBlur,
                .commitInlineRenameOnOutsideClick,
            ]
        )

        XCTAssertEqual(
            Set(WorkspaceShortcutDefinition.globalCoordinatorCatalog.map(\.command)),
            [.selectPreviousFrame, .selectNextFrame, .toggleFramePlayback, .assignSubsetToSelectedRegions]
        )
        XCTAssertEqual(
            definitions.first(where: { $0.command == .applyProjectSettings })?.ownership,
            .sheetLocal
        )
        XCTAssertEqual(
            definitions.first(where: { $0.command == .cancelProjectSettings })?.ownership,
            .sheetLocal
        )
        XCTAssertEqual(
            definitions.first(where: { $0.command == .dismissCutOnboarding })?.ownership,
            .sheetLocal
        )
        XCTAssertEqual(
            definitions.first(where: { $0.command == .submitInlineRename })?.ownership,
            .textEntryLocal
        )
        XCTAssertEqual(
            definitions.first(where: { $0.command == .cancelInlineRename })?.ownership,
            .textEntryLocal
        )
    }

    func testResolveMoveCommandRoutesFrameNavigationWhenWorkspaceIsActive() {
        let coordinator = WorkspaceShortcutCoordinator()
        let context = makeContext()

        XCTAssertEqual(coordinator.resolveMoveCommand(.left, context: context), .selectPreviousFrame)
        XCTAssertEqual(coordinator.resolveMoveCommand(.right, context: context), .selectNextFrame)
        XCTAssertNil(coordinator.resolveMoveCommand(.up, context: context))
    }

    func testResolveMoveCommandSuppressesWhenModalIsPresented() {
        let coordinator = WorkspaceShortcutCoordinator()
        let context = makeContext(isModalPresented: true)

        XCTAssertNil(coordinator.resolveMoveCommand(.left, context: context))
        XCTAssertNil(coordinator.resolveMoveCommand(.right, context: context))
    }

    func testResolveMoveCommandSuppressesWhenNoActiveCutExists() {
        let coordinator = WorkspaceShortcutCoordinator()
        let context = makeContext(hasActiveCut: false)

        XCTAssertNil(coordinator.resolveMoveCommand(.left, context: context))
    }

    func testResolveKeyDownRoutesSpacePlaybackWithoutModifiers() {
        let coordinator = WorkspaceShortcutCoordinator()
        let context = makeContext()

        XCTAssertEqual(
            coordinator.resolveKeyDown(keyCode: 49, modifierFlags: [], context: context),
            .toggleFramePlayback
        )
    }

    func testResolveKeyDownRoutesArrowKeyRawEventsForFrameNavigation() {
        let coordinator = WorkspaceShortcutCoordinator()
        let context = makeContext()

        XCTAssertEqual(
            coordinator.resolveKeyDown(keyCode: 123, modifierFlags: [.function], context: context),
            .selectPreviousFrame
        )
        XCTAssertEqual(
            coordinator.resolveKeyDown(keyCode: 124, modifierFlags: [.function], context: context),
            .selectNextFrame
        )
    }

    func testResolveKeyDownSuppressesWhenTextInputIsFocused() {
        let coordinator = WorkspaceShortcutCoordinator()
        let context = makeContext(isTextInputFocused: true)

        XCTAssertNil(coordinator.resolveKeyDown(keyCode: 49, modifierFlags: [], context: context))
    }

    func testResolveKeyDownRejectsModifiedSpaceShortcut() {
        let coordinator = WorkspaceShortcutCoordinator()
        let context = makeContext()

        XCTAssertNil(coordinator.resolveKeyDown(keyCode: 49, modifierFlags: [.command], context: context))
        XCTAssertNil(coordinator.resolveKeyDown(keyCode: 49, modifierFlags: [.option], context: context))
    }

    @MainActor
    func testShortcutMonitorIgnoresNonKeyWindow() {
        let view = WorkspaceShortcutMonitorView()

        XCTAssertFalse(view.shouldConsumeEvents(for: nil))
        XCTAssertFalse(view.shouldConsumeEvents(for: StubWindow(isKeyWindow: false)))
        XCTAssertTrue(view.shouldConsumeEvents(for: StubWindow(isKeyWindow: true)))
    }

    private func makeContext(
        hasActiveCut: Bool = true,
        isModalPresented: Bool = false,
        isTextInputFocused: Bool = false
    ) -> WorkspaceShortcutContext {
        WorkspaceShortcutContext(
            hasActiveCut: hasActiveCut,
            isModalPresented: isModalPresented,
            isTextInputFocused: isTextInputFocused
        )
    }
}

private final class StubWindow: NSWindow {
    private let stubIsKeyWindow: Bool

    init(isKeyWindow: Bool) {
        self.stubIsKeyWindow = isKeyWindow
        super.init(
            contentRect: .init(x: 0, y: 0, width: 100, height: 100),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
    }

    override var isKeyWindow: Bool {
        stubIsKeyWindow
    }
}
