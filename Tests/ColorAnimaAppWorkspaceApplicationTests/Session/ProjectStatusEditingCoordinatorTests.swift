import XCTest
@testable import ColorAnimaAppWorkspaceApplication

final class ProjectStatusEditingCoordinatorTests: XCTestCase {
    func testAddStatusAppendsUniqueStatusFromActivePaletteAndSelectsIt() throws {
        let ids = makeIDs()
        var state = ProjectStatusEditingState(
            groups: [
                makeGroup(
                    id: ids.groupID,
                    subsetID: ids.subsetID,
                    palettes: [
                        StatusPalette(name: "default", roles: .neutral),
                        StatusPalette(name: "night", roles: activeRoles)
                    ]
                )
            ],
            selectedSubsetID: ids.subsetID,
            activeStatusName: "night"
        )

        let newName = ProjectStatusEditingCoordinator.addStatus(
            to: ids.subsetID,
            suggestedName: " night ",
            in: &state
        )

        XCTAssertEqual(newName, "status_2")
        let subset = try XCTUnwrap(state.groups.first?.subsets.first)
        XCTAssertEqual(subset.palettes.map(\.name), ["default", "night", "status_2"])
        XCTAssertEqual(subset.palettes.last?.roles, activeRoles)
        XCTAssertEqual(state.activeStatusName, "status_2")
        XCTAssertTrue(state.metadataDirty)
        XCTAssertTrue(state.needsColorSystemRefresh)
        XCTAssertEqual(state.rewriteRequests, [])
    }

    func testAddStatusUsesSuggestedNameWhenUnique() throws {
        let ids = makeIDs()
        var state = ProjectStatusEditingState(
            groups: [makeGroup(id: ids.groupID, subsetID: ids.subsetID)],
            selectedSubsetID: ids.subsetID
        )

        let newName = ProjectStatusEditingCoordinator.addStatus(
            to: ids.subsetID,
            suggestedName: " cleanup ",
            in: &state
        )

        XCTAssertEqual(newName, "cleanup")
        XCTAssertEqual(try XCTUnwrap(state.groups.first?.subsets.first).palettes.map(\.name), ["default", "cleanup"])
        XCTAssertEqual(state.activeStatusName, "cleanup")
    }

    func testRenameStatusNormalizesNameUpdatesActiveStatusAndRecordsRewrite() throws {
        let ids = makeIDs()
        var state = ProjectStatusEditingState(
            groups: [
                makeGroup(
                    id: ids.groupID,
                    subsetID: ids.subsetID,
                    palettes: [
                        StatusPalette(name: "default", roles: .neutral),
                        StatusPalette(name: "night", roles: activeRoles)
                    ]
                )
            ],
            selectedSubsetID: ids.subsetID,
            activeStatusName: "night"
        )

        let renamed = ProjectStatusEditingCoordinator.renameStatus(
            in: ids.subsetID,
            from: "night",
            to: " dusk ",
            in: &state
        )

        XCTAssertTrue(renamed)
        XCTAssertEqual(try XCTUnwrap(state.groups.first?.subsets.first).palettes.map(\.name), ["default", "dusk"])
        XCTAssertEqual(state.activeStatusName, "dusk")
        XCTAssertTrue(state.metadataDirty)
        XCTAssertTrue(state.needsColorSystemRefresh)
        XCTAssertEqual(
            state.rewriteRequests,
            [ProjectAssignmentSyncRequest(subsetID: ids.subsetID, oldStatusName: "night", newStatusName: "dusk")]
        )
    }

    func testRenameStatusRejectsDuplicateOrBlankNames() throws {
        let ids = makeIDs()
        let originalGroup = makeGroup(
            id: ids.groupID,
            subsetID: ids.subsetID,
            palettes: [
                StatusPalette(name: "default", roles: .neutral),
                StatusPalette(name: "night", roles: activeRoles)
            ]
        )
        var state = ProjectStatusEditingState(groups: [originalGroup], selectedSubsetID: ids.subsetID)

        XCTAssertFalse(
            ProjectStatusEditingCoordinator.renameStatus(
                in: ids.subsetID,
                from: "night",
                to: " default ",
                in: &state
            )
        )
        XCTAssertFalse(
            ProjectStatusEditingCoordinator.renameStatus(
                in: ids.subsetID,
                from: "night",
                to: "   ",
                in: &state
            )
        )

        XCTAssertEqual(state.groups, [originalGroup])
        XCTAssertFalse(state.metadataDirty)
        XCTAssertFalse(state.needsColorSystemRefresh)
        XCTAssertEqual(state.rewriteRequests, [])
    }

    func testRemoveStatusUsesFallbackAndRecordsRewrite() throws {
        let ids = makeIDs()
        var state = ProjectStatusEditingState(
            groups: [
                makeGroup(
                    id: ids.groupID,
                    subsetID: ids.subsetID,
                    palettes: [
                        StatusPalette(name: "default", roles: .neutral),
                        StatusPalette(name: "night", roles: activeRoles)
                    ]
                )
            ],
            selectedSubsetID: ids.subsetID,
            activeStatusName: "night"
        )

        let removed = ProjectStatusEditingCoordinator.removeStatus(
            in: ids.subsetID,
            named: "night",
            fallbackStatusName: " default ",
            in: &state
        )

        XCTAssertTrue(removed)
        XCTAssertEqual(try XCTUnwrap(state.groups.first?.subsets.first).palettes.map(\.name), ["default"])
        XCTAssertEqual(state.activeStatusName, "default")
        XCTAssertTrue(state.metadataDirty)
        XCTAssertTrue(state.needsColorSystemRefresh)
        XCTAssertEqual(
            state.rewriteRequests,
            [ProjectAssignmentSyncRequest(subsetID: ids.subsetID, oldStatusName: "night", newStatusName: "default")]
        )
    }

    func testRemoveStatusRejectsLastStatusAndMissingFallback() throws {
        let ids = makeIDs()
        let originalGroup = makeGroup(id: ids.groupID, subsetID: ids.subsetID)
        var state = ProjectStatusEditingState(groups: [originalGroup], selectedSubsetID: ids.subsetID)

        XCTAssertFalse(
            ProjectStatusEditingCoordinator.removeStatus(
                in: ids.subsetID,
                named: "default",
                fallbackStatusName: "missing",
                in: &state
            )
        )

        XCTAssertEqual(state.groups, [originalGroup])
        XCTAssertFalse(state.metadataDirty)
        XCTAssertFalse(state.needsColorSystemRefresh)
        XCTAssertEqual(state.rewriteRequests, [])
    }

    private var activeRoles: ColorRoles {
        ColorRoles(
            base: RGBAColor(red: 0.1, green: 0.2, blue: 0.3),
            highlight: RGBAColor(red: 0.4, green: 0.5, blue: 0.6),
            shadow: RGBAColor(red: 0.7, green: 0.8, blue: 0.9)
        )
    }

    private func makeIDs() -> (groupID: UUID, subsetID: UUID) {
        (
            UUID(uuidString: "00000000-0000-0000-0000-0000000F0010")!,
            UUID(uuidString: "00000000-0000-0000-0000-0000000F0020")!
        )
    }

    private func makeGroup(
        id: UUID,
        subsetID: UUID,
        palettes: [StatusPalette] = [StatusPalette(name: "default", roles: .neutral)]
    ) -> ColorSystemGroup {
        ColorSystemGroup(
            id: id,
            name: "character",
            subsets: [
                ColorSystemSubset(
                    id: subsetID,
                    name: "skin",
                    palettes: palettes
                )
            ]
        )
    }
}
