import ColorAnimaAppWorkspaceApplication
import ColorAnimaAppWorkspaceDesignSystem
import SwiftUI

struct WorkspaceStatusStrip: View {
    let feedback: LongRunningActionFeedback

    var body: some View {
        Group {
            switch feedback.state {
            case .queued, .failed:
                EmptyView()

            case .running:
                TimelineView(.periodic(from: feedback.startedAt ?? .now, by: 0.25)) { _ in
                    if feedback.hasExceededQuietThreshold {
                        pill(
                            primary: feedback.actionLabel,
                            secondary: feedback.progressText,
                            showSpinner: true,
                            accent: .accentColor
                        )
                    } else {
                        EmptyView()
                    }
                }

            case .completed:
                pill(primary: "\(feedback.actionLabel) - Done", secondary: nil, showSpinner: false, accent: .green)

            case .cancelled:
                pill(primary: "\(feedback.actionLabel) - Cancelled", secondary: nil, showSpinner: false, accent: .secondary)
            }
        }
        .padding(.top, 12)
        .frame(maxWidth: .infinity, alignment: .top)
        .allowsHitTesting(false)
    }
}

private extension WorkspaceStatusStrip {
    func pill(primary: String, secondary: String?, showSpinner: Bool, accent: Color) -> some View {
        HStack(spacing: 8) {
            if showSpinner {
                ProgressView()
                    .controlSize(.small)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(primary)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)
                if let secondary, secondary.isEmpty == false {
                    Text(secondary)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(WorkspaceChromeStyle.badgeFill)
        .overlay {
            Capsule()
                .strokeBorder(accent.opacity(0.25), lineWidth: 1)
        }
        .clipShape(.capsule)
    }
}
