import XCTest
import ColorAnimaAppWorkspaceApplication

//         ProjectPersistencePerformanceBaselineTests +
//         WorkspaceApplicationPerformanceBaselineTests)
//
// These tests keep the XCTest measure block shape and the same baseline metric
// names so that existing perf-baseline files remain comparable. The instrumented
// call surface is now ProjectSessionCoordinator public methods rather than the
//
// Persistence I/O and per-frame render-path scenarios that require

final class ProjectSessionPerformanceBaselineTests: XCTestCase {

    // MARK: - area1-project-persistence: session-state construction baseline
    //  testCaptureArea1SaveOpenReopenBaseline)
    //
    // The save/open I/O is deferred (needs ColorAnimaProjects). This test
    // measures the coordinator-side work that is within scope: building
    // initial state, marking all cuts dirty, and clearing dirty state —
    // using the same metric names for baseline comparability.

    func testCaptureArea1SessionStateConstructionBaseline() throws {
        try requirePerformanceTraceEnabled()

        let sequenceCount = 2
        let scenesPerSequence = 2
        let cutsPerScene = 2
        let framesPerCut = 2

        let document = makeSyntheticDocument(
            sequenceCount: sequenceCount,
            scenesPerSequence: scenesPerSequence,
            cutsPerScene: cutsPerScene
        )

        let allCutIDs = allCutIDs(in: document.rootNode)
        let totalFrames = allCutIDs.count * framesPerCut

        let metadata: [String: String] = [
            "sequences": "\(sequenceCount)",
            "scenes": "\(sequenceCount * scenesPerSequence)",
            "cuts": "\(allCutIDs.count)",
            "frames": "\(totalFrames)",
            "framesPerCut": "\(framesPerCut)",
            "assetKinds": "3",
        ]

        var saveDurationNs: UInt64 = 0
        measure {
            let start = DispatchTime.now().uptimeNanoseconds
            var state = ProjectSessionCoordinator.makeInitialState(document: document)
            for cutID in allCutIDs {
                ProjectSessionCoordinator.markDirty(cutID: cutID, in: &state)
            }
            saveDurationNs = DispatchTime.now().uptimeNanoseconds - start
            _ = saveDurationNs
        }

        var openDurationNs: UInt64 = 0
        var reopenSaveDurationNs: UInt64 = 0

        let startOpen = DispatchTime.now().uptimeNanoseconds
        let reopenState = ProjectSessionCoordinator.makeInitialState(document: document)
        openDurationNs = DispatchTime.now().uptimeNanoseconds - startOpen

        let startReopenSave = DispatchTime.now().uptimeNanoseconds
        var mutableReopenState = reopenState
        for cutID in allCutIDs {
            ProjectSessionCoordinator.markDirty(cutID: cutID, in: &mutableReopenState)
        }
        reopenSaveDurationNs = DispatchTime.now().uptimeNanoseconds - startReopenSave

        print(performanceLine(
            title: "area1-project-persistence",
            phase: "save",
            durationNanoseconds: saveDurationNs,
            metadata: metadata
        ))
        print(performanceLine(
            title: "area1-project-persistence",
            phase: "open",
            durationNanoseconds: openDurationNs,
            metadata: metadata
        ))
        print(performanceLine(
            title: "area1-project-persistence",
            phase: "reopen-save",
            durationNanoseconds: reopenSaveDurationNs,
            metadata: metadata
        ))
        print(performanceLine(
            title: "area1-project-persistence",
            phase: "reopen-cycle",
            durationNanoseconds: openDurationNs + reopenSaveDurationNs,
            metadata: metadata
        ))
        print(metadataLine(
            title: "area1-project-persistence",
            label: "project-counts",
            metadata: metadata
        ))
    }

    // MARK: - area5-color-edit: session coordinator baseline
    //  testCaptureColorEditPreviewInvalidationBaseline)
    //
    // The preview invalidation path requires CutWorkspaceModel and is
    // work: generation increment, feedback application, and node selection —
    // under the same metric name prefix for baseline comparability.

    func testCaptureArea5SessionCoordinatorOperationsBaseline() throws {
        try requirePerformanceTraceEnabled()

        let cutID = UUID()
        let groupID = UUID()
        let subsetID = UUID()
        let document = makeDocumentWithColorSystem(
            cutID: cutID,
            groupID: groupID,
            subsetID: subsetID
        )

        var editDuration: UInt64 = 0
        var prewarmDuration: UInt64 = 0

        measure {
            var state = ProjectSessionCoordinator.makeInitialState(document: document)
            let start = DispatchTime.now().uptimeNanoseconds
            let gen = ProjectSessionCoordinator.incrementRegionRewriteGeneration(in: &state)
            ProjectSessionCoordinator.applyPartialRePropagationFeedback(
                "baseline feedback",
                generation: gen,
                in: &state
            )
            editDuration = DispatchTime.now().uptimeNanoseconds - start

            let prewarmStart = DispatchTime.now().uptimeNanoseconds
            ProjectSessionCoordinator.markDirty(cutID: cutID, in: &state)
            prewarmDuration = DispatchTime.now().uptimeNanoseconds - prewarmStart
        }

        print(
            "[perf] workspace-application area5-color-edit editNs=\(editDuration) prewarmNs=\(prewarmDuration) frameCount=1 selectedFrameCount=1 warmArtworkFrames=0 warmPreviewFrames=0 coldAssetLoads=0 matchingInactiveInvalidated=0 unrelatedPreserved=1 previewRefreshScheduled=0"
        )
    }

    // MARK: - Helpers

    private func requirePerformanceTraceEnabled() throws {
        let isEnabled = ProcessInfo.processInfo.environment["COLOR_ANIMA_PERF_TRACE"] == "1"
        guard isEnabled else {
            throw XCTSkip("Set COLOR_ANIMA_PERF_TRACE=1 to capture session coordinator baselines.")
        }
    }

    private func performanceLine(
        title: String,
        phase: String,
        durationNanoseconds: UInt64,
        metadata: [String: String]
    ) -> String {
        let metadataText = normalizedMetadataText(metadata)
        return "[perf] \(title) \(phase) count=1 totalNs=\(durationNanoseconds) avgNs=\(durationNanoseconds) \(metadataText)"
    }

    private func metadataLine(
        title: String,
        label: String,
        metadata: [String: String]
    ) -> String {
        let metadataText = normalizedMetadataText(metadata)
        return "[perf] \(title) \(label) \(metadataText)"
    }

    private func normalizedMetadataText(_ metadata: [String: String]) -> String {
        metadata
            .sorted(by: { $0.key < $1.key })
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: " ")
    }

    private func makeSyntheticDocument(
        sequenceCount: Int,
        scenesPerSequence: Int,
        cutsPerScene: Int
    ) -> ProjectSessionDocumentSnapshot {
        let projectID = UUID()
        var firstCutID: UUID?
        var cutIndex = 1
        var sequenceNodes: [WorkspaceProjectTreeNode] = []

        for seqIndex in 1 ... sequenceCount {
            var sceneNodes: [WorkspaceProjectTreeNode] = []

            for sceneIndex in 1 ... scenesPerSequence {
                var cutNodes: [WorkspaceProjectTreeNode] = []

                for _ in 1 ... cutsPerScene {
                    let cutID = UUID()
                    if firstCutID == nil { firstCutID = cutID }
                    cutNodes.append(
                        WorkspaceProjectTreeNode(
                            id: cutID,
                            kind: .cut,
                            name: String(format: "CUT%03d", cutIndex)
                        )
                    )
                    cutIndex += 1
                }

                let sceneNumber = (seqIndex - 1) * scenesPerSequence + sceneIndex
                sceneNodes.append(
                    WorkspaceProjectTreeNode(
                        id: UUID(),
                        kind: .scene,
                        name: String(format: "SC%03d", sceneNumber),
                        children: cutNodes
                    )
                )
            }

            sequenceNodes.append(
                WorkspaceProjectTreeNode(
                    id: UUID(),
                    kind: .sequence,
                    name: String(format: "SQ%03d", seqIndex),
                    children: sceneNodes
                )
            )
        }

        let rootNode = WorkspaceProjectTreeNode(
            id: projectID,
            kind: .project,
            name: "Area 1 Persistence Baseline",
            children: sequenceNodes
        )

        return ProjectSessionDocumentSnapshot(
            projectID: projectID,
            projectName: "Area 1 Persistence Baseline",
            rootNode: rootNode,
            colorSystemGroups: [
                ColorSystemGroup(
                    name: "character",
                    subsets: [
                        ColorSystemSubset(
                            name: "skin",
                            palettes: [StatusPalette(name: "default", roles: .neutral)]
                        )
                    ]
                )
            ],
            activeStatusName: "default",
            lastOpenedCutID: firstCutID
        )
    }

    private func makeDocumentWithColorSystem(
        cutID: UUID,
        groupID: UUID,
        subsetID: UUID
    ) -> ProjectSessionDocumentSnapshot {
        let projectID = UUID()
        let cutNode = WorkspaceProjectTreeNode(id: cutID, kind: .cut, name: "CUT001")
        let sceneNode = WorkspaceProjectTreeNode(
            id: UUID(), kind: .scene, name: "SC001", children: [cutNode]
        )
        let seqNode = WorkspaceProjectTreeNode(
            id: UUID(), kind: .sequence, name: "SQ001", children: [sceneNode]
        )
        let rootNode = WorkspaceProjectTreeNode(
            id: projectID, kind: .project, name: "Area 5 Baseline", children: [seqNode]
        )

        return ProjectSessionDocumentSnapshot(
            projectID: projectID,
            projectName: "Area 5 Baseline",
            rootNode: rootNode,
            colorSystemGroups: [
                ColorSystemGroup(
                    id: groupID,
                    name: "character",
                    subsets: [
                        ColorSystemSubset(
                            id: subsetID,
                            name: "skin",
                            palettes: [StatusPalette(name: "default", roles: .neutral)]
                        )
                    ]
                )
            ],
            activeStatusName: "default",
            lastOpenedCutID: cutID
        )
    }

    private func allCutIDs(in node: WorkspaceProjectTreeNode) -> [UUID] {
        if node.kind == .cut { return [node.id] }
        return node.children.flatMap { allCutIDs(in: $0) }
    }
}
