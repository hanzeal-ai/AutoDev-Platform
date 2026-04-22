import SwiftUI

struct ProjectDetailLifecycleSection: View {
    @ObservedObject var viewModel: ShellViewModel

    var body: some View {
        DashboardCard(title: "生命周期轨道") {
            ProjectDetailLifecycleTrack(
                current: viewModel.state.selectedProject?.lifecycleStage ?? viewModel.state.activeDetailStage
            )
        }
    }
}

private struct ProjectDetailLifecycleTrack: View {
    let current: DeliveryLifecycleStage

    var body: some View {
        let stages = DeliveryLifecycleStage.allCases
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Array(stages.enumerated()), id: \.element.id) { index, stage in
                    let isCurrent = stage == current
                    let isReached = stage.order <= current.order

                    HStack(spacing: 6) {
                        Circle()
                            .fill(isReached ? Color.accentColor : Color.secondary.opacity(0.35))
                            .frame(width: 7, height: 7)
                        Text(stage.rawValue)
                            .font(.caption.weight(.medium))
                            .foregroundColor(isCurrent ? .primary : .secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 999, style: .continuous)
                            .fill(isCurrent ? Color.accentColor.opacity(0.16) : Color(nsColor: .controlBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 999, style: .continuous)
                            .stroke(isCurrent ? Color.accentColor.opacity(0.45) : Color.clear, lineWidth: 1)
                    )
                    .accessibilityLabel("\(stage.rawValue)\(isCurrent ? "，当前阶段" : "")")

                    if index < stages.count - 1 {
                        Capsule(style: .circular)
                            .fill(isReached ? Color.accentColor.opacity(0.6) : Color.secondary.opacity(0.2))
                            .frame(width: 14, height: 3)
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }
}
