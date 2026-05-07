import AppKit
import ColorAnimaAppWorkspaceApplication
import ColorAnimaAppWorkspaceCutEditor
import ColorAnimaAppWorkspaceDesignSystem
import SwiftUI

struct CutWorkspaceInspectorView: View {
    @Bindable var model: WorkspaceHostModel
    let roleSwatchColorPanelPresenter: any RoleSwatchColorPanelPresenting

    @State private var editingGroupID: UUID?
    @State private var editingGroupName = ""
    @State private var editingSubsetID: UUID?
    @State private var editingSubsetName = ""
    @State private var editingRegionID: UUID?
    @State private var editingRegionName = ""
    @State private var confidenceFilter: ConfidenceReviewFilter = .all

    init(
        model: WorkspaceHostModel,
        roleSwatchColorPanelPresenter: any RoleSwatchColorPanelPresenting = NoOpRoleSwatchColorPanelPresenter.shared
    ) {
        self.model = model
        self.roleSwatchColorPanelPresenter = roleSwatchColorPanelPresenter
    }

    var body: some View {
        let selectedGroupID = model.selectedGroupID
        let selectedSubsetID = model.selectedSubsetID
        let selectedRegionID = model.selectedRegion?.id

        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                trackingQueueSection
                confidenceSection
                ruleSection
                renderSettingsSection
                colorSystemSection
                regionsSection
            }
            .padding(WorkspaceFoundation.Metrics.space4)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            Rectangle()
                .fill(WorkspaceFoundation.Surface.surfaceFill)
                .ignoresSafeArea()
        }
        .onChange(of: selectedGroupID) {
            guard editingGroupID != selectedGroupID else { return }
            cancelGroupRename()
            cancelSubsetRename()
            cancelRegionRename()
        }
        .onChange(of: selectedSubsetID) {
            guard editingSubsetID != selectedSubsetID else { return }
            cancelSubsetRename()
        }
        .onChange(of: selectedRegionID) {
            guard editingRegionID != nil, editingRegionID != selectedRegionID else { return }
            cancelRegionRename()
        }
    }

    @ViewBuilder
    private var trackingQueueSection: some View {
        if let trackingQueuePresentation = model.trackingQueuePresentation {
            inspectorCard {
                InspectorQueueNavigator(
                    state: trackingQueuePresentation,
                    onNavigateToQueueItem: { index in model.navigateToQueueItem(at: index) },
                    onAccept: { index in model.acceptQueueItem(at: index) },
                    onReassign: { index in
                        model.navigateToQueueItem(at: index)
                        model.reassignTrackingQueueItem()
                    },
                    onSkip: { index in model.skipQueueItem(at: index) }
                )
            }
        }
    }

    private var confidenceSection: some View {
        inspectorCard {
            ConfidenceTimelineView(
                rows: model.confidenceFrameRows,
                selectedFrameID: model.activeCutWorkspace?.selectedFrameID,
                filter: $confidenceFilter,
                onSelectFrame: { frameID in model.selectFrame(frameID) }
            )
        }
    }

    private var ruleSection: some View {
        inspectorCard(title: "Rules") {
            RuleEditorView(
                ruleSet: model.colorRuleSet,
                onAdd: {
                    model.addRule(ColorRule(
                        id: UUID(),
                        name: "New Rule",
                        condition: .any,
                        color: .white
                    ))
                },
                onRemove: { id in model.removeRule(id: id) },
                onMove: { source, destination in model.moveRule(fromOffsets: source, toOffset: destination) },
                onUpdate: { rule in model.updateRule(rule) },
                onWhatIfHover: { ruleID, color in
                    model.triggerWhatIfPreview(ruleID: ruleID, simulatedColor: color)
                },
                onWhatIfClear: model.clearWhatIfPreview
            )
        }
    }

    private var renderSettingsSection: some View {
        inspectorCard(title: "Render Settings") {
            RenderSettingsView(
                settings: model.renderSettings,
                onUpdate: { model.updateRenderSettings($0) }
            )
        }
    }

    private var colorSystemSection: some View {
        inspectorCard(title: "Color System") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Groups")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Add Group") {
                        model.addGroup()
                    }
                    .controlSize(.small)
                }

                ForEach(model.groups) { group in
                    groupRow(group)
                }

                if let selectedGroupIndex = model.selectedGroupIndex {
                    Divider()

                    HStack {
                        Text("Subsets")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Add Subset") {
                            model.addSubset()
                        }
                        .controlSize(.small)
                    }

                    ForEach(model.groups[selectedGroupIndex].subsets) { subset in
                        SubsetCardView(
                            subset: subset,
                            isSelected: model.selectedSubsetID == subset.id,
                            deleteResetToken: AnyHashable(subset.id),
                            activeStatusName: model.activeStatusName,
                            selectedStatusNames: Array(model.selectedStatusNames).sorted(),
                            editingSubsetID: editingSubsetID,
                            editingSubsetName: $editingSubsetName,
                            onSelectSubset: { model.selectSubset($0) },
                            onStartRename: startSubsetRename,
                            onCommitRename: commitSubsetRename,
                            onCancelRename: cancelSubsetRename,
                            onSetActiveStatus: { model.setActiveStatus($0) },
                            onAddStatus: { model.addStatus(suggestedName: nil) },
                            onRenameStatus: { _, newName in model.renameActiveStatus(to: newName) },
                            onRemoveStatus: { model.removeActiveStatus() },
                            onRemoveSubset: { model.removeSubset($0) },
                            baseColorSelection: model.selectedSubsetID == subset.id ? colorBinding(role: \.base) : nil,
                            highlightColorSelection: model.selectedSubsetID == subset.id ? colorBinding(role: \.highlight) : nil,
                            shadowColorSelection: model.selectedSubsetID == subset.id ? colorBinding(role: \.shadow) : nil,
                            highlightEnabledBinding: model.selectedSubsetID == subset.id ? model.subsetFlagBinding(\.isHighlightEnabled) : nil,
                            shadowEnabledBinding: model.selectedSubsetID == subset.id ? model.subsetFlagBinding(\.isShadowEnabled) : nil,
                            colorPanelPresenter: roleSwatchColorPanelPresenter
                        )
                    }
                }
            }
        }
    }

    private var regionsSection: some View {
        inspectorCard(title: "Regions") {
            VStack(alignment: .leading, spacing: 12) {
                if let summary = model.regionsSummary {
                    HStack(spacing: 8) {
                        regionSummaryBadge("Total", value: summary.totalRegionCount)
                        regionSummaryBadge("Assigned", value: summary.assignedRegionCount)
                        regionSummaryBadge("Open", value: summary.unassignedRegionCount)
                    }
                }

                selectedRegionCard
                regionList
            }
        }
    }

    @ViewBuilder
    private var selectedRegionCard: some View {
        if let state = model.selectedRegionInspectorState {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(state.displayName)
                        .font(.headline)
                    Spacer()
                    Text(state.regionIDSummary)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                }

                regionMetadataRow("Centroid", state.centroidSummary)
                regionMetadataRow("Bounds", state.boundsSummary)
                regionMetadataRow("Assignment", state.assignmentSummary)

                InspectorTrackingPanel(
                    state: state,
                    onAccept: { promoteToAnchor in
                        model.acceptSelectedRegionTracking(promoteToAnchor: promoteToAnchor)
                    },
                    onReassign: { promoteToAnchor in
                        model.reassignSelectedRegionTracking(promoteToAnchor: promoteToAnchor)
                    },
                    onClear: model.clearSelectedRegionTracking
                )

                HStack(spacing: 8) {
                    Button(state.assignActionTitle) {
                        model.assignSelectedRegionToSelectedSubset()
                    }
                    .disabled(!state.canAssignToSelectedSubset)

                    Button(state.clearActionTitle) {
                        model.clearSelectedRegionAssignment()
                    }
                    .disabled(!state.canClearAssignment)

                    Button("Delete", role: .destructive) {
                        model.deleteSelectedRegions()
                    }
                }
                .controlSize(.small)
            }
            .padding(WorkspaceFoundation.Metrics.space3)
            .background(WorkspaceFoundation.Surface.sectionBackground)
            .clipShape(.rect(cornerRadius: WorkspaceFoundation.Metrics.cardCornerRadius))
        }
    }

    @ViewBuilder
    private var regionList: some View {
        if let summary = model.regionsSummary, summary.rows.isEmpty == false {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(summary.rows) { row in
                    Button {
                        model.selectRegion(row.id)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(row.displayName)
                                    .font(.caption.weight(.semibold))
                                Text(assignmentLabel(row.assignment))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if row.isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                        .padding(.horizontal, WorkspaceFoundation.Metrics.space2_5)
                        .padding(.vertical, WorkspaceFoundation.Metrics.space2)
                        .background(
                            row.isSelected ? WorkspaceFoundation.Surface.rowHighlight : Color.clear,
                            in: RoundedRectangle(cornerRadius: WorkspaceFoundation.Metrics.compactControlCornerRadius)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        } else if model.extractionStatus == .done {
            Text("No regions were detected for this cut.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            Text("Run extraction to populate region controls.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func groupRow(_ group: ColorSystemGroup) -> some View {
        HStack(spacing: 8) {
            if editingGroupID == group.id {
                TextField("Group name", text: $editingGroupName)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        commitGroupRename(group.id)
                    }
                Button("Done") {
                    commitGroupRename(group.id)
                }
                .controlSize(.small)
                Button("Cancel") {
                    cancelGroupRename()
                }
                .controlSize(.small)
            } else {
                Button {
                    model.selectGroup(group.id)
                } label: {
                    Text(group.name)
                        .font(.callout.weight(model.selectedGroupID == group.id ? .semibold : .regular))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)

                Button("Rename") {
                    startGroupRename(group)
                }
                .controlSize(.small)

                HoverDeleteConfirmButton(
                    isVisible: model.groups.count > 1,
                    resetToken: AnyHashable(group.id)
                ) {
                    model.removeGroup(group.id)
                }
            }
        }
        .padding(.horizontal, WorkspaceFoundation.Metrics.space2_5)
        .padding(.vertical, WorkspaceFoundation.Metrics.space2)
        .background(
            model.selectedGroupID == group.id ? WorkspaceFoundation.Surface.rowHighlight : Color.clear,
            in: RoundedRectangle(cornerRadius: WorkspaceFoundation.Metrics.compactControlCornerRadius)
        )
    }

    private func inspectorCard<Content: View>(
        title: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Text(title)
                    .font(.headline)
            }
            content()
        }
        .padding(WorkspaceFoundation.Metrics.space3_5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(WorkspaceChromeStyle.cardFill)
        .overlay {
            RoundedRectangle(cornerRadius: WorkspaceFoundation.Metrics.cardCornerRadius)
                .strokeBorder(WorkspaceChromeStyle.cardStroke, lineWidth: 1)
        }
        .clipShape(.rect(cornerRadius: WorkspaceFoundation.Metrics.cardCornerRadius))
    }

    private func colorBinding(role: WritableKeyPath<ColorRoles, RGBAColor>) -> Binding<Color> {
        let rgbaBinding = model.colorBinding(role: role)
        return Binding(
            get: {
                rgbaBinding.wrappedValue.swiftUIColor
            },
            set: { newColor in
                rgbaBinding.wrappedValue = RGBAColor(color: newColor)
            }
        )
    }

    private func startGroupRename(_ group: ColorSystemGroup) {
        editingGroupID = group.id
        editingGroupName = group.name
    }

    private func commitGroupRename(_ groupID: UUID) {
        model.renameGroup(groupID, to: editingGroupName)
        cancelGroupRename()
    }

    private func cancelGroupRename() {
        editingGroupID = nil
        editingGroupName = ""
    }

    private func startSubsetRename(_ subset: ColorSystemSubset) {
        model.selectSubset(subset.id)
        editingSubsetID = subset.id
        editingSubsetName = subset.name
    }

    private func commitSubsetRename(_ subsetID: UUID) {
        model.renameSubset(subsetID, to: editingSubsetName)
        cancelSubsetRename()
    }

    private func cancelSubsetRename() {
        editingSubsetID = nil
        editingSubsetName = ""
    }

    private func cancelRegionRename() {
        editingRegionID = nil
        editingRegionName = ""
    }

    private func regionSummaryBadge(_ label: String, value: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("\(value)")
                .font(.caption.weight(.semibold))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(WorkspaceFoundation.Metrics.space2)
        .background(WorkspaceFoundation.Surface.sectionBackground)
        .clipShape(.rect(cornerRadius: WorkspaceFoundation.Metrics.compactControlCornerRadius))
    }

    private func regionMetadataRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption.monospaced())
        }
    }

    private func assignmentLabel(_ assignment: RegionListAssignment?) -> String {
        switch assignment {
        case let .assigned(groupName, subsetName):
            "\(groupName) / \(subsetName)"
        case .unassigned:
            "Unassigned"
        case nil:
            "No assignment"
        }
    }
}

private extension RGBAColor {
    init(color: Color) {
        let nsColor = NSColor(color)
        let rgb = nsColor.usingColorSpace(.sRGB) ?? nsColor
        self.init(
            red: Double(rgb.redComponent),
            green: Double(rgb.greenComponent),
            blue: Double(rgb.blueComponent),
            alpha: Double(rgb.alphaComponent)
        )
    }
}
