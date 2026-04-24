import SwiftUI

struct ProjectDetailLifecycleSection: View {
    @ObservedObject var viewModel: ShellViewModel

    var body: some View {
        DashboardCard(title: "生命周期轨道") {
            ProjectDetailLifecycleTrack(
                current: viewModel.state.selectedProject?.lifecycleStage ?? viewModel.state.activeDetailStage,
                viewing: viewModel.state.activeDetailStage,
                onSelectStage: { stage in
                    viewModel.selectDetailStage(stage)
                }
            )
        }
    }
}

struct ProjectDetailLifecycleTrack: View {
    let current: DeliveryLifecycleStage
    let viewing: DeliveryLifecycleStage
    let onSelectStage: (DeliveryLifecycleStage) -> Void

    var body: some View {
        let stages = DeliveryLifecycleStage.allCases
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Array(stages.enumerated()), id: \.element.id) { index, stage in
                    let isViewing = stage == viewing
                    let isReached = stage.order <= current.order
                    let isClickable = isReached && stage != viewing

                    HStack(spacing: 6) {
                        Circle()
                            .fill(isReached ? Color.accentColor : Color.secondary.opacity(0.35))
                            .frame(width: 7, height: 7)
                        Text(stage.rawValue)
                            .font(.caption.weight(.medium))
                            .foregroundColor(isViewing ? .primary : .secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 999, style: .continuous)
                            .fill(isViewing ? Color.accentColor.opacity(0.16) : Color(nsColor: .controlBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 999, style: .continuous)
                            .stroke(isViewing ? Color.accentColor.opacity(0.45) : Color.clear, lineWidth: 1)
                    )
                    .if(isClickable) { view in
                        view.onTapGesture { onSelectStage(stage) }
                    }
                    .opacity(isClickable ? 1.0 : (isViewing ? 1.0 : 0.6))
                    .accessibilityLabel("\(stage.rawValue)\(isViewing ? "，正在查看" : (isReached ? "，可点击回溯" : ""))")
                    .help(isClickable ? "点击查看 \(stage.rawValue) 阶段详情" : "")

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

extension View {
    @ViewBuilder
    func `if`<Transform: View>(_ condition: Bool, transform: (Self) -> Transform) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
