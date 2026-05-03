import ColorAnimaAppWorkspaceApplication
import ColorAnimaAppWorkspaceDesignSystem
import SwiftUI

struct ProjectTreeFooter: View {
    let selectedNodeID: UUID?
    let selectedNode: WorkspaceProjectTreeNode?
    let rootNode: WorkspaceProjectTreeNode
    let onCreateSequence: () -> Void
    let onCreateScene: (UUID) -> Void
    let onCreateCut: (UUID) -> Void

    var body: some View {
        let experimentalCreateActions = ProjectTreeActionRules.experimentalCreateActions(
            selectedNodeID: selectedNodeID,
            selectedNode: selectedNode,
            rootNode: rootNode
        )

        return createFooterControl(experimentalCreateActions)
        .padding(ProjectTreeSidebarMetrics.edgePadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(WorkspaceFoundation.Surface.surfaceFill)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(WorkspaceFoundation.Stroke.divider)
                .frame(height: 1)
        }
    }

    private func createFooterControl(
        _ actions: ProjectTreeActionRules.ExperimentalCreateActions
    ) -> some View {
        ExperimentalCreateFooterSlot(
            actions: actions,
            performAction: performCreateAction
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func performCreateAction(_ action: ProjectTreeActionRules.PrimaryCreateAction) {
        switch action.kind {
        case .sequence:
            onCreateSequence()
        case let .scene(sequenceID):
            onCreateScene(sequenceID)
        case let .cut(sceneID):
            onCreateCut(sceneID)
        case .disabled:
            break
        }
    }
}

private struct ExperimentalCreateFooterSlot: View {
    let actions: ProjectTreeActionRules.ExperimentalCreateActions
    let performAction: (ProjectTreeActionRules.PrimaryCreateAction) -> Void

    var body: some View {
        HStack {
            Spacer(minLength: 0)
            ExperimentalConcentricCreateButton(actions: actions, performAction: performAction)
                .frame(width: 50, height: 50)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Create New Item")
                .accessibilityHint("Use the outer or inner circle to create different item types")
                .accessibilityAddTraits(.isButton)
                .disabled(!actions.isEnabled)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
        .opacity(actions.isEnabled ? 1 : 0.55)
    }
}

private struct ExperimentalConcentricCreateButton: View {
    private enum HoverZone {
        case outer
        case inner
    }

    let actions: ProjectTreeActionRules.ExperimentalCreateActions
    let performAction: (ProjectTreeActionRules.PrimaryCreateAction) -> Void

    @State private var hoveredZone: HoverZone?

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let outerDiameter = side * 0.88
            let innerDiameter = side * 0.44

            ZStack {
                Circle()
                    .fill(outerFill)
                    .overlay {
                        Circle()
                            .stroke(outerStroke, lineWidth: 1)
                    }
                    .frame(width: outerDiameter, height: outerDiameter)

                Circle()
                    .fill(innerFill)
                    .overlay {
                        Circle()
                            .stroke(innerStroke, lineWidth: 1)
                    }
                    .frame(width: innerDiameter, height: innerDiameter)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Circle())
            .onContinuousHover(coordinateSpace: .local) { phase in
                switch phase {
                case let .active(location):
                    hoveredZone = hoverZone(for: location, in: proxy.size)
                case .ended:
                    hoveredZone = nil
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onEnded { value in
                        guard let action = action(for: value.location, in: proxy.size) else { return }
                        guard action.isEnabled else { return }
                        performAction(action)
                    }
            )
        }
    }

    private func action(for location: CGPoint, in size: CGSize) -> ProjectTreeActionRules.PrimaryCreateAction? {
        switch hoverZone(for: location, in: size) {
        case .inner:
            return actions.inner
        case .outer:
            return actions.outer
        case nil:
            return nil
        }
    }

    private func hoverZone(for location: CGPoint, in size: CGSize) -> HoverZone? {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let distance = hypot(location.x - center.x, location.y - center.y)
        let side = min(size.width, size.height)
        let outerRadius = side * 0.44
        let innerRadius = side * 0.22
        guard distance <= outerRadius else { return nil }
        return distance <= innerRadius ? .inner : .outer
    }

    private var outerFill: Color {
        switch hoveredZone {
        case .outer:
            return WorkspaceChromeStyle.Sidebar.interactiveHoverFill
        case .inner:
            return WorkspaceChromeStyle.Sidebar.interactiveHoverFill.opacity(0.45)
        case nil:
            return WorkspaceChromeStyle.Sidebar.concentricCreateOuterRestFill
        }
    }

    private var innerFill: Color {
        switch hoveredZone {
        case .inner:
            return WorkspaceChromeStyle.Sidebar.interactivePressedFill
        case .outer:
            return WorkspaceChromeStyle.Sidebar.interactiveHoverFill.opacity(0.65)
        case nil:
            return WorkspaceChromeStyle.Sidebar.concentricCreateInnerRestFill
        }
    }

    private var outerStroke: Color {
        switch hoveredZone {
        case .outer:
            return WorkspaceChromeStyle.Sidebar.interactiveHoverStroke
        case .inner:
            return WorkspaceChromeStyle.Sidebar.interactiveHoverStroke.opacity(0.85)
        case nil:
            return WorkspaceChromeStyle.Sidebar.interactiveIdleStroke
        }
    }

    private var innerStroke: Color {
        switch hoveredZone {
        case .inner:
            return WorkspaceChromeStyle.Sidebar.interactiveHoverStroke
        case .outer:
            return WorkspaceChromeStyle.Sidebar.interactiveHoverStroke.opacity(0.8)
        case nil:
            return WorkspaceChromeStyle.Sidebar.interactiveIdleStroke.opacity(1.15)
        }
    }
}
