import SwiftUI

// Layout constants for the inspector composite. Defined here because
// WorkspaceFoundation tokens are package-internal and unavailable to this target.
private enum InspectorLayout {
    static let sidebarWidth: CGFloat = 220
    static let sectionPadding: CGFloat = 16
    static let pickerPadding: CGFloat = 12
    static let sidebarHeaderPadding: CGFloat = 12
    static let badgeHPadding: CGFloat = 4
    static let badgeVPadding: CGFloat = 2
    static let subsetSwatchCornerRadius: CGFloat = 3
    static let infoRowMinSpacing: CGFloat = 4
    static let rowVPadding: CGFloat = 2
    static let actionSpacing: CGFloat = 8
    static let confidenceFrameWidth: CGFloat = 48
    static let confidenceValueWidth: CGFloat = 36
}

/// Integrated preview: Inspector panel (full-width, focused view).
/// approximate: real inspector views (InspectorTrackingPanel, CutWorkspaceGapInspectorView,
/// SubsetCardView, ConfidenceTimelineView) are package-internal to
/// ColorAnimaAppWorkspaceCutEditor and cannot be imported from a separate SPM target.
/// This composite renders an approximate layout using SwiftUI system primitives that
/// mirrors the real inspector chrome structure and data categories.
struct InspectorCompositeView: View {
    @State private var selectedTab: InspectorTab = .region

    var body: some View {
        HStack(spacing: 0) {
            sideBar
            Divider()
            detail
        }
        .frame(minWidth: 800, minHeight: 540)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Tabs

    private enum InspectorTab: String, CaseIterable {
        case region = "Region"
        case gapReview = "Gap Review"
        case subsets = "Subsets"
        case confidence = "Confidence"
    }

    // MARK: - Sidebar (region list)

    private var sideBar: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Regions")
                .font(.body)
                .fontWeight(.semibold)
                .padding(InspectorLayout.sidebarHeaderPadding)

            Divider()

            List(selection: .constant("R-0042")) {
                ForEach(stubRegions, id: \.id) { region in
                    HStack {
                        Circle()
                            .fill(region.color)
                            .frame(width: 10, height: 10)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(region.name)
                                .font(.callout)
                            Text(region.id)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                        Text(region.badge)
                            .font(.caption2)
                            .padding(.horizontal, InspectorLayout.badgeHPadding)
                            .padding(.vertical, InspectorLayout.badgeVPadding)
                            .background(region.badgeColor.opacity(0.15))
                            .foregroundStyle(region.badgeColor)
                            .clipShape(Capsule())
                    }
                    .tag(region.id)
                }
            }
            .listStyle(.sidebar)
        }
        .frame(width: InspectorLayout.sidebarWidth)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Detail panel

    private var detail: some View {
        VStack(alignment: .leading, spacing: 0) {
            Picker("", selection: $selectedTab) {
                ForEach(InspectorTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(InspectorLayout.pickerPadding)

            Divider()

            ScrollView {
                switch selectedTab {
                case .region:
                    regionDetailContent
                case .gapReview:
                    gapReviewContent
                case .subsets:
                    subsetsContent
                case .confidence:
                    confidenceContent
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Region detail

    private var regionDetailContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Identity")
            infoRow("Region ID", "R-0042")
            infoRow("Centroid", "(820, 440)")
            infoRow("Bounds", "124×88 px")
            infoRow("Assignment", "Hair — Shadow")

            Divider()
            sectionHeader("Tracking")
            infoRow("State", "Tracked (anchor)")
            infoRow("Confidence", "94%")
            infoRow("Reasons", "shape, centroid")
            infoRow("Manual override", "None")

            Divider()
            sectionHeader("Actions")
            Toggle("Promote to anchor", isOn: .constant(false))
                .font(.caption)
            HStack(spacing: InspectorLayout.actionSpacing) {
                Button("Accept") {}
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                Button("Reassign") {}
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                Button("Clear", role: .destructive) {}
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                Spacer(minLength: 0)
            }
        }
        .padding(InspectorLayout.sectionPadding)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    // MARK: - Gap review

    private var gapReviewContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Gap Review")
            Text("Pending review")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()
            infoRow("Area", "320 px")
            infoRow("Pixel count", "1,284")
            infoRow("Confidence", "0.71")

            Divider()
            sectionHeader("Actions")
            HStack(spacing: InspectorLayout.actionSpacing) {
                Button("Apply Suggested") {}
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                Button("Pick Color") {}
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                Button("Ignore") {}
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                Button("Reject") {}
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                Spacer(minLength: 0)
            }
        }
        .padding(InspectorLayout.sectionPadding)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    // MARK: - Subsets

    private var subsetsContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Color Subsets")
            ForEach(stubSubsets, id: \.name) { subset in
                HStack {
                    RoundedRectangle(cornerRadius: InspectorLayout.subsetSwatchCornerRadius)
                        .fill(subset.color)
                        .frame(width: 18, height: 18)
                    Text(subset.name)
                        .font(.callout)
                    Spacer(minLength: 0)
                    Text(subset.status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, InspectorLayout.rowVPadding)
            }
        }
        .padding(InspectorLayout.sectionPadding)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    // MARK: - Confidence

    private var confidenceContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Confidence Review")
            ForEach(Array(stubConfidenceRows.enumerated()), id: \.offset) { _, row in
                HStack {
                    Text(row.frameLabel)
                        .font(.caption)
                        .monospacedDigit()
                        .frame(width: InspectorLayout.confidenceFrameWidth, alignment: .leading)
                    ProgressView(value: row.confidence)
                        .progressViewStyle(.linear)
                        .tint(row.confidence > 0.8 ? .green : row.confidence > 0.6 ? .orange : .red)
                    Text("\(Int(row.confidence * 100))%")
                        .font(.caption)
                        .monospacedDigit()
                        .frame(width: InspectorLayout.confidenceValueWidth, alignment: .trailing)
                }
            }
        }
        .padding(InspectorLayout.sectionPadding)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.body)
            .fontWeight(.semibold)
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: InspectorLayout.infoRowMinSpacing)
            Text(value)
                .font(.caption)
                .monospacedDigit()
        }
    }

    // MARK: - Stub data

    private struct StubRegion {
        let id: String
        let name: String
        let color: Color
        let badge: String
        let badgeColor: Color
    }

    private let stubRegions: [StubRegion] = [
        StubRegion(id: "R-0042", name: "Hair — Shadow", color: .purple, badge: "94%", badgeColor: .green),
        StubRegion(id: "R-0043", name: "Skin — Base", color: .orange, badge: "Ref", badgeColor: .blue),
        StubRegion(id: "R-0044", name: "Jacket — Mid", color: .indigo, badge: "78% ⚠", badgeColor: .orange),
        StubRegion(id: "R-0045", name: "Eyes", color: .brown, badge: "— ?", badgeColor: .secondary),
        StubRegion(id: "R-0046", name: "Background", color: .gray, badge: "91%", badgeColor: .green),
    ]

    private struct StubSubset {
        let name: String
        let color: Color
        let status: String
    }

    private let stubSubsets: [StubSubset] = [
        StubSubset(name: "Hair — Shadow", color: .purple, status: "Assigned"),
        StubSubset(name: "Skin — Base", color: .orange, status: "Assigned"),
        StubSubset(name: "Jacket — Mid", color: .indigo, status: "Review"),
        StubSubset(name: "Eyes", color: .brown, status: "Pending"),
    ]

    private struct StubConfidenceRow {
        let frameLabel: String
        let confidence: Double
    }

    private let stubConfidenceRows: [StubConfidenceRow] = [
        StubConfidenceRow(frameLabel: "F 001", confidence: 1.0),
        StubConfidenceRow(frameLabel: "F 002", confidence: 0.94),
        StubConfidenceRow(frameLabel: "F 003", confidence: 0.78),
        StubConfidenceRow(frameLabel: "F 004", confidence: 0.45),
        StubConfidenceRow(frameLabel: "F 005", confidence: 0.61),
        StubConfidenceRow(frameLabel: "F 006", confidence: 0.91),
    ]
}
