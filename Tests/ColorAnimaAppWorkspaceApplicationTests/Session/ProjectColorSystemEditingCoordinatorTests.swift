import XCTest
@testable import ColorAnimaAppWorkspaceApplication

final class ProjectColorSystemEditingCoordinatorTests: XCTestCase {
    func testUpdateSelectedPaletteRoleRecordsRefreshRequestAndPrewarmSplit() {
        let ids = makeIDs()
        let activeCutID = makeID(40)
        let inactiveCutID = makeID(41)
        let frames = [makeID(50), makeID(51), makeID(52), makeID(53)]
        var state = ProjectColorSystemEditingState(
            groups: [
                makeGroup(id: ids.groupID, subsetID: ids.subsetID, palettes: ["day"])
            ],
            selectedGroupID: ids.groupID,
            selectedSubsetID: ids.subsetID,
            activeStatusName: "day",
            activeCutID: activeCutID,
            workspaces: [
                activeCutID: ProjectColorSystemWorkspaceUsageState(
                    selectedFrameID: frames[1],
                    frameIDsInDisplayOrder: frames,
                    subsetIDsByFrameID: [
                        frames[0]: [ids.subsetID],
                        frames[2]: [ids.subsetID],
                        frames[3]: [ids.subsetID]
                    ]
                ),
                inactiveCutID: ProjectColorSystemWorkspaceUsageState(
                    frameIDsInDisplayOrder: [makeID(60)],
                    subsetIDsByFrameID: [makeID(60): [ids.subsetID]]
                )
            ]
        )
        let newColor = RGBAColor(red: 0.2, green: 0.3, blue: 0.4)

        let didUpdate = ProjectColorSystemEditingCoordinator.updateSelectedPaletteRole(
            \.base,
            to: newColor,
            in: &state
        )

        XCTAssertTrue(didUpdate)
        XCTAssertEqual(state.groups[0].subsets[0].palettes[0].roles.base, newColor)
        XCTAssertTrue(state.metadataDirty)
        XCTAssertTrue(state.needsColorSystemRefresh)
        XCTAssertEqual(
            state.refreshRequests,
            [
                ProjectColorSystemEditRefreshRequest(
                    scope: .overlay,
                    editedSubsetID: ids.subsetID,
                    activeCutID: activeCutID,
                    inactiveCutIDs: [inactiveCutID],
                    prewarmAdjacentFrameIDs: [frames[0], frames[2]],
                    prewarmRestFrameIDs: [frames[3]]
                )
            ]
        )
    }

    func testUpdateSelectedPaletteRoleIgnoresMissingPaletteAndUnchangedValue() {
        let ids = makeIDs()
        var missingPaletteState = ProjectColorSystemEditingState(
            groups: [makeGroup(id: ids.groupID, subsetID: ids.subsetID, palettes: ["day"])],
            selectedGroupID: ids.groupID,
            selectedSubsetID: ids.subsetID,
            activeStatusName: "night"
        )
        var unchangedState = ProjectColorSystemEditingState(
            groups: [makeGroup(id: ids.groupID, subsetID: ids.subsetID, palettes: ["day"])],
            selectedGroupID: ids.groupID,
            selectedSubsetID: ids.subsetID,
            activeStatusName: "day"
        )

        let missingPaletteDidUpdate = ProjectColorSystemEditingCoordinator.updateSelectedPaletteRole(
            \.base,
            to: .black,
            in: &missingPaletteState
        )
        let unchangedDidUpdate = ProjectColorSystemEditingCoordinator.updateSelectedPaletteRole(
            \.base,
            to: .white,
            in: &unchangedState
        )

        XCTAssertFalse(missingPaletteDidUpdate)
        XCTAssertFalse(unchangedDidUpdate)
        XCTAssertFalse(missingPaletteState.metadataDirty)
        XCTAssertFalse(unchangedState.metadataDirty)
        XCTAssertEqual(missingPaletteState.refreshRequests, [])
        XCTAssertEqual(unchangedState.refreshRequests, [])
    }

    func testUpdateSelectedSubsetFlagRecordsGuideRefreshScope() {
        let ids = makeIDs()
        var state = ProjectColorSystemEditingState(
            groups: [makeGroup(id: ids.groupID, subsetID: ids.subsetID)],
            selectedGroupID: ids.groupID,
            selectedSubsetID: ids.subsetID
        )

        let didUpdate = ProjectColorSystemEditingCoordinator.updateSelectedSubsetFlag(
            \.isHighlightEnabled,
            to: false,
            in: &state
        )

        XCTAssertTrue(didUpdate)
        XCTAssertFalse(state.groups[0].subsets[0].isHighlightEnabled)
        XCTAssertTrue(state.metadataDirty)
        XCTAssertTrue(state.needsColorSystemRefresh)
        XCTAssertEqual(
            state.refreshRequests,
            [
                ProjectColorSystemEditRefreshRequest(
                    scope: .highlightGuide,
                    editedSubsetID: ids.subsetID
                )
            ]
        )
    }

    func testAffectedInactiveFrameIDsSplitSeparatesAdjacentAndRest() {
        let ids = makeIDs()
        let frames = [makeID(70), makeID(71), makeID(72), makeID(73), makeID(74)]
        let workspace = ProjectColorSystemWorkspaceUsageState(
            selectedFrameID: frames[2],
            frameIDsInDisplayOrder: frames,
            subsetIDsByFrameID: [
                frames[0]: [ids.subsetID],
                frames[1]: [ids.subsetID],
                frames[3]: [ids.subsetID],
                frames[4]: [ids.subsetID]
            ]
        )

        let split = ProjectColorSystemEditingCoordinator.affectedInactiveFrameIDsSplit(
            in: workspace,
            editedSubsetID: ids.subsetID
        )

        XCTAssertEqual(split.adjacent, [frames[1], frames[3]])
        XCTAssertEqual(split.rest, [frames[0], frames[4]])
    }

    func testAffectedInactiveFrameIDsSplitHandlesFirstAndLastActiveFrames() {
        let ids = makeIDs()
        let frames = [makeID(70), makeID(71), makeID(72), makeID(73)]
        let subsetIDsByFrameID = Dictionary(uniqueKeysWithValues: frames.map { ($0, Set([ids.subsetID])) })
        let firstWorkspace = ProjectColorSystemWorkspaceUsageState(
            selectedFrameID: frames[0],
            frameIDsInDisplayOrder: frames,
            subsetIDsByFrameID: subsetIDsByFrameID
        )
        let lastWorkspace = ProjectColorSystemWorkspaceUsageState(
            selectedFrameID: frames[3],
            frameIDsInDisplayOrder: frames,
            subsetIDsByFrameID: subsetIDsByFrameID
        )

        let firstSplit = ProjectColorSystemEditingCoordinator.affectedInactiveFrameIDsSplit(
            in: firstWorkspace,
            editedSubsetID: ids.subsetID
        )
        let lastSplit = ProjectColorSystemEditingCoordinator.affectedInactiveFrameIDsSplit(
            in: lastWorkspace,
            editedSubsetID: ids.subsetID
        )

        XCTAssertEqual(firstSplit.adjacent, [frames[1]])
        XCTAssertEqual(firstSplit.rest, [frames[2], frames[3]])
        XCTAssertEqual(lastSplit.adjacent, [frames[2]])
        XCTAssertEqual(lastSplit.rest, [frames[0], frames[1]])
    }

    func testAffectedInactiveFrameIDsSplitExcludesNeighborsWithoutEditedSubset() {
        let ids = makeIDs()
        let frames = [makeID(70), makeID(71), makeID(72), makeID(73), makeID(74)]
        let workspace = ProjectColorSystemWorkspaceUsageState(
            selectedFrameID: frames[2],
            frameIDsInDisplayOrder: frames,
            subsetIDsByFrameID: [
                frames[0]: [ids.subsetID],
                frames[2]: [ids.subsetID]
            ]
        )

        let split = ProjectColorSystemEditingCoordinator.affectedInactiveFrameIDsSplit(
            in: workspace,
            editedSubsetID: ids.subsetID
        )

        XCTAssertEqual(split.adjacent, [])
        XCTAssertEqual(split.rest, [frames[0]])
    }

    func testAffectedInactiveFrameIDsSplitReturnsEmptyForSingleFrameCut() {
        let ids = makeIDs()
        let frameID = makeID(70)
        let workspace = ProjectColorSystemWorkspaceUsageState(
            selectedFrameID: frameID,
            frameIDsInDisplayOrder: [frameID],
            subsetIDsByFrameID: [frameID: [ids.subsetID]]
        )

        let split = ProjectColorSystemEditingCoordinator.affectedInactiveFrameIDsSplit(
            in: workspace,
            editedSubsetID: ids.subsetID
        )

        XCTAssertEqual(split.adjacent, [])
        XCTAssertEqual(split.rest, [])
    }

    func testUpdateSelectedPaletteRoleSkipsAdjacentPrewarmWhenNoNeighborsUseEditedSubset() {
        let ids = makeIDs()
        let activeCutID = makeID(40)
        let frames = [makeID(70), makeID(71), makeID(72), makeID(73), makeID(74)]
        var state = ProjectColorSystemEditingState(
            groups: [
                makeGroup(id: ids.groupID, subsetID: ids.subsetID, palettes: ["day"])
            ],
            selectedGroupID: ids.groupID,
            selectedSubsetID: ids.subsetID,
            activeStatusName: "day",
            activeCutID: activeCutID,
            workspaces: [
                activeCutID: ProjectColorSystemWorkspaceUsageState(
                    selectedFrameID: frames[2],
                    frameIDsInDisplayOrder: frames,
                    subsetIDsByFrameID: [
                        frames[0]: [ids.subsetID],
                        frames[2]: [ids.subsetID],
                        frames[4]: [ids.subsetID]
                    ]
                )
            ]
        )

        let didUpdate = ProjectColorSystemEditingCoordinator.updateSelectedPaletteRole(
            \.base,
            to: RGBAColor(red: 0.2, green: 0.3, blue: 0.4),
            in: &state
        )

        XCTAssertTrue(didUpdate)
        XCTAssertEqual(
            state.refreshRequests,
            [
                ProjectColorSystemEditRefreshRequest(
                    scope: .overlay,
                    editedSubsetID: ids.subsetID,
                    activeCutID: activeCutID,
                    prewarmAdjacentFrameIDs: [],
                    prewarmRestFrameIDs: [frames[0], frames[4]]
                )
            ]
        )
    }

    func testRenameGroupAndSubsetTrimNamesAndMarkRefresh() {
        let ids = makeIDs()
        var state = ProjectColorSystemEditingState(
            groups: [
                makeGroup(
                    id: ids.groupID,
                    subsetID: ids.subsetID,
                    groupName: "Characters",
                    subsetName: "Skin"
                )
            ],
            selectedGroupID: ids.groupID,
            selectedSubsetID: ids.subsetID
        )

        ProjectColorSystemEditingCoordinator.renameGroup(ids.groupID, to: " Leads ", in: &state)
        ProjectColorSystemEditingCoordinator.renameSubset(ids.subsetID, to: " Face ", in: &state)

        XCTAssertEqual(state.groups.first?.name, "Leads")
        XCTAssertEqual(state.groups.first?.subsets.first?.name, "Face")
        XCTAssertTrue(state.metadataDirty)
        XCTAssertTrue(state.needsColorSystemRefresh)
    }

    func testRenameRejectsBlankAndMissingTargets() {
        let ids = makeIDs()
        let group = makeGroup(id: ids.groupID, subsetID: ids.subsetID)
        var state = ProjectColorSystemEditingState(groups: [group])

        ProjectColorSystemEditingCoordinator.renameGroup(ids.groupID, to: "  ", in: &state)
        ProjectColorSystemEditingCoordinator.renameSubset(UUID(), to: "Other", in: &state)

        XCTAssertEqual(state.groups, [group])
        XCTAssertFalse(state.metadataDirty)
        XCTAssertFalse(state.needsColorSystemRefresh)
    }

    func testAddGroupUsesUniqueNameActiveStatusPaletteAndSelectsNewGroup() {
        let ids = makeIDs()
        var state = ProjectColorSystemEditingState(
            groups: [
                makeGroup(id: ids.groupID, subsetID: ids.subsetID, groupName: "group_1")
            ],
            selectedGroupID: ids.groupID,
            selectedSubsetID: ids.subsetID,
            activeStatusName: "night"
        )

        let newGroupID = ProjectColorSystemEditingCoordinator.addGroup(in: &state)

        XCTAssertEqual(state.groups.count, 2)
        XCTAssertEqual(state.groups.last?.id, newGroupID)
        XCTAssertEqual(state.groups.last?.name, "group_2")
        XCTAssertEqual(state.groups.last?.subsets.first?.name, "subset_1")
        XCTAssertEqual(state.groups.last?.subsets.first?.palettes.first?.name, "night")
        XCTAssertEqual(state.selectedGroupID, newGroupID)
        XCTAssertEqual(state.selectedSubsetID, state.groups.last?.subsets.first?.id)
        XCTAssertTrue(state.metadataDirty)
        XCTAssertTrue(state.needsColorSystemRefresh)
    }

    func testAddGroupStartsDefaultNameSequenceAndSelectsNewGroup() {
        let ids = makeIDs()
        var state = ProjectColorSystemEditingState(
            groups: [
                makeGroup(id: ids.groupID, subsetID: ids.subsetID)
            ],
            selectedGroupID: ids.groupID,
            selectedSubsetID: ids.subsetID,
            activeStatusName: "default"
        )

        let newGroupID = ProjectColorSystemEditingCoordinator.addGroup(in: &state)

        XCTAssertEqual(state.groups.count, 2)
        XCTAssertEqual(state.groups.last?.id, newGroupID)
        XCTAssertEqual(state.groups.last?.name, "group_1")
        XCTAssertEqual(state.groups.last?.subsets.first?.name, "subset_1")
        XCTAssertEqual(state.selectedGroupID, newGroupID)
        XCTAssertEqual(state.selectedSubsetID, state.groups.last?.subsets.first?.id)
        XCTAssertTrue(state.metadataDirty)
        XCTAssertTrue(state.needsColorSystemRefresh)
    }

    func testRemoveGroupRecordsClearRequestAndFallsBackToAdjacentGroup() {
        let ids = makeIDs()
        let secondGroupID = makeID(10)
        let secondSubsetID = makeID(11)
        var state = ProjectColorSystemEditingState(
            groups: [
                makeGroup(id: ids.groupID, subsetID: ids.subsetID),
                makeGroup(id: secondGroupID, subsetID: secondSubsetID, groupName: "Props")
            ],
            selectedGroupID: ids.groupID,
            selectedSubsetID: ids.subsetID
        )

        ProjectColorSystemEditingCoordinator.removeGroup(ids.groupID, in: &state)

        XCTAssertEqual(state.groups.map(\.id), [secondGroupID])
        XCTAssertEqual(state.selectedGroupID, secondGroupID)
        XCTAssertEqual(state.selectedSubsetID, secondSubsetID)
        XCTAssertEqual(state.assignmentClearRequests, [.group(ids.groupID)])
        XCTAssertTrue(state.metadataDirty)
        XCTAssertTrue(state.needsColorSystemRefresh)
    }

    func testAddSubsetRequiresSelectedGroupAndSelectsNewSubset() {
        let ids = makeIDs()
        var state = ProjectColorSystemEditingState(
            groups: [
                makeGroup(id: ids.groupID, subsetID: ids.subsetID)
            ],
            selectedGroupID: ids.groupID,
            selectedSubsetID: ids.subsetID,
            activeStatusName: "cleanup"
        )

        let newSubsetID = ProjectColorSystemEditingCoordinator.addSubset(in: &state)

        XCTAssertEqual(state.groups.first?.subsets.count, 2)
        XCTAssertEqual(state.groups.first?.subsets.last?.id, newSubsetID)
        XCTAssertEqual(state.groups.first?.subsets.last?.name, "subset_1")
        XCTAssertEqual(state.groups.first?.subsets.last?.palettes.first?.name, "cleanup")
        XCTAssertEqual(state.selectedGroupID, ids.groupID)
        XCTAssertEqual(state.selectedSubsetID, newSubsetID)
        XCTAssertTrue(state.metadataDirty)
        XCTAssertTrue(state.needsColorSystemRefresh)
    }

    func testRemoveSubsetRecordsClearRequestAndFallsBackWithinSelectedGroup() {
        let ids = makeIDs()
        let fallbackSubsetID = makeID(20)
        let group = ColorSystemGroup(
            id: ids.groupID,
            name: "Characters",
            subsets: [
                ColorSystemSubset(id: ids.subsetID, name: "Skin", palettes: [
                    StatusPalette(name: "day", roles: .neutral)
                ]),
                ColorSystemSubset(id: fallbackSubsetID, name: "Hair", palettes: [
                    StatusPalette(name: "night", roles: .neutral)
                ])
            ]
        )
        var state = ProjectColorSystemEditingState(
            groups: [group],
            selectedGroupID: ids.groupID,
            selectedSubsetID: ids.subsetID,
            activeStatusName: "day"
        )

        ProjectColorSystemEditingCoordinator.removeSubset(ids.subsetID, in: &state)

        XCTAssertEqual(state.groups.first?.subsets.map(\.id), [fallbackSubsetID])
        XCTAssertEqual(state.selectedGroupID, ids.groupID)
        XCTAssertEqual(state.selectedSubsetID, fallbackSubsetID)
        XCTAssertEqual(state.activeStatusName, "night")
        XCTAssertEqual(state.assignmentClearRequests, [.subset(ids.subsetID)])
        XCTAssertTrue(state.metadataDirty)
        XCTAssertTrue(state.needsColorSystemRefresh)
    }

    func testSelectGroupAndSubsetReconcileActiveStatus() {
        let ids = makeIDs()
        let secondGroupID = makeID(30)
        let secondSubsetID = makeID(31)
        var state = ProjectColorSystemEditingState(
            groups: [
                makeGroup(id: ids.groupID, subsetID: ids.subsetID, palettes: ["day"]),
                makeGroup(id: secondGroupID, subsetID: secondSubsetID, groupName: "Props", palettes: ["night"])
            ],
            selectedGroupID: ids.groupID,
            selectedSubsetID: ids.subsetID,
            activeStatusName: "day"
        )

        ProjectColorSystemEditingCoordinator.selectGroup(secondGroupID, in: &state)

        XCTAssertEqual(state.selectedGroupID, secondGroupID)
        XCTAssertEqual(state.selectedSubsetID, secondSubsetID)
        XCTAssertEqual(state.activeStatusName, "night")

        ProjectColorSystemEditingCoordinator.selectSubset(ids.subsetID, in: &state)

        XCTAssertEqual(state.selectedGroupID, ids.groupID)
        XCTAssertEqual(state.selectedSubsetID, ids.subsetID)
        XCTAssertEqual(state.activeStatusName, "day")
    }

    func testNormalizeColorSelectionDropsStaleIDsAndDefaultsWithoutSubsets() {
        let ids = makeIDs()
        var state = ProjectColorSystemEditingState(
            groups: [
                ColorSystemGroup(id: ids.groupID, name: "Empty", subsets: [])
            ],
            selectedGroupID: UUID(),
            selectedSubsetID: UUID(),
            activeStatusName: "day"
        )

        ProjectColorSystemEditingCoordinator.normalizeColorSelection(in: &state)

        XCTAssertEqual(state.selectedGroupID, ids.groupID)
        XCTAssertNil(state.selectedSubsetID)
        XCTAssertEqual(state.activeStatusName, "default")
    }

    func testSetActiveStatusMarksMetadataDirty() {
        var state = ProjectColorSystemEditingState(activeStatusName: "day")

        ProjectColorSystemEditingCoordinator.setActiveStatus("night", in: &state)

        XCTAssertEqual(state.activeStatusName, "night")
        XCTAssertTrue(state.metadataDirty)
    }

    private func makeIDs() -> (groupID: UUID, subsetID: UUID) {
        (makeID(1), makeID(2))
    }

    private func makeGroup(
        id: UUID,
        subsetID: UUID,
        groupName: String = "Characters",
        subsetName: String = "Skin",
        palettes: [String] = ["day", "night"]
    ) -> ColorSystemGroup {
        ColorSystemGroup(
            id: id,
            name: groupName,
            subsets: [
                ColorSystemSubset(
                    id: subsetID,
                    name: subsetName,
                    palettes: palettes.map { StatusPalette(name: $0, roles: .neutral) }
                )
            ]
        )
    }

    private func makeID(_ value: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", value))!
    }
}
